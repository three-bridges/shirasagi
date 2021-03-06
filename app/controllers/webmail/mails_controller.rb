require "net/imap"
class Webmail::MailsController < ApplicationController
  include Webmail::BaseFilter
  include Sns::CrudFilter
  helper Webmail::MailHelper

  model Webmail::Mail

  skip_before_action :set_selected_items
  before_action :imap_login
  before_action :apply_recent_filters, only: [:index]
  before_action :set_mailbox
  before_action :set_item, only: [:show, :edit, :update, :delete, :destroy]
  before_action :set_view_name, only: [:new, :create, :edit, :update]
  before_action :set_crumbs

  private

  def set_crumbs
    mailbox = Webmail::Mailbox.new(imap: @imap, name: Net::IMAP.decode_utf7(params[:mailbox]))
    @crumbs << [t("webmail.mail"), webmail_mails_path]
    @crumbs << [mailbox.basename, { action: :index }]
    @webmail_other_account_path = :webmail_mails_path
  end

  def fix_params
    @imap.account_scope.merge(cur_user: @cur_user, mailbox: @mailbox, imap: @imap)
  end

  def set_item
    if SS.config.webmail.store_mails
      @item = @imap.mails.find_and_store params[:id], :body
    else
      @item = @imap.mails.find params[:id], :body
    end
    @item.attributes = fix_params
  end

  def set_view_name
    @addon_basic_name = @model.t :to
  end

  def crud_redirect_url
    { action: :index }
  end

  def get_uids
    ids = params[:ids].presence || [params[:id]]
    ids.map(&:to_i)
  end

  def apply_recent_filters
    @mailboxes = @imap.mailboxes.load
    @mailboxes.apply_recent_filters
  end

  def set_mailbox
    @navi_mailboxes = true
    @mailbox = params[:mailbox]

    if params[:action] == 'index' || params[:action] =~ /^(set_|unset_)/
      @imap.select(@mailbox)
    else
      @imap.examine(@mailbox)
    end
  end

  public

  def index
    @sys_notices = Sys::Notice.and_public.webmail_admin_notice.page(1).per(2)

    @items = @imap.mails.
      mailbox(@mailbox).
      search(params[:s]).
      page(params[:page]).
      per(50).
      all
  end

  def show
    if @item.unseen?
      @imap.select(@mailbox)
      @item.set_seen
      @mailboxes = @imap.mailboxes.update_status
    end
  end

  def new
    @item = @model.new pre_params.merge(fix_params)
    @item.new_mail

    # send from address
    if data = params[:item].presence
      @item.to << data[:to].to_s if data[:to].present?
    end
  end

  def edit
    raise "404" unless @item.draft?
    @item.set_ref_files(@item.attachments)
  end

  def update
    @item.attributes = get_params

    if params[:commit] == I18n.t('ss.buttons.draft_save')
      notice = nil
      resp = @item.save_draft
    else
      notice = t('ss.notice.sent')
      resp = @item.send_mail
    end

    @item.destroy_files
    render_create resp, notice: notice
  end

  def header_view
    if SS.config.webmail.store_mails
      @item = @imap.mails.find_and_store params[:id]
    else
      @item = @imap.mails.find params[:id]
    end

    render plain: @item.header, layout: false
  end

  def source_view
    if SS.config.webmail.store_mails
      @item = @imap.mails.find_and_store params[:id], :rfc822
    else
      @item = @imap.mails.find params[:id], :rfc822
    end

    render plain: @item.rfc822, layout: false
  end

  def download
    if SS.config.webmail.store_mails
      @item = @imap.mails.find_and_store params[:id], :rfc822
    else
      @item = @imap.mails.find params[:id], :rfc822
    end

    send_data @item.rfc822, filename: "#{@item.subject}.eml",
              content_type: 'message/rfc822', disposition: :attachment
  end

  def parts
    if SS.config.webmail.store_mails
      part = @imap.mails.find_part_and_store params[:id], params[:section]
    else
      part = @imap.mails.find_part params[:id], params[:section]
    end
    disposition = part.image? ? :inline : :attachment

    send_data part.decoded, filename: part.filename,
              content_type: part.content_type, disposition: disposition
  end

  def reply
    if SS.config.webmail.store_mails
      @ref = @imap.mails.find_and_store params[:id], :body
    else
      @ref = @imap.mails.find params[:id], :body
    end

    @item = @model.new pre_params.merge(fix_params)
    @item.new_reply(@ref)
    render :new
  end

  def reply_all
    if SS.config.webmail.store_mails
      @ref = @imap.mails.find_and_store params[:id], :body
    else
      @ref = @imap.mails.find params[:id], :body
    end

    @item = @model.new pre_params.merge(fix_params)
    @item.new_reply_all(@ref)
    render :new
  end

  def forward
    if SS.config.webmail.store_mails
      @ref = @imap.mails.find_and_store params[:id], :body
    else
      @ref = @imap.mails.find params[:id], :body
    end

    @item = @model.new pre_params.merge(fix_params)
    @item.new_forward(@ref)
    render :new
  end

  def create
    @item = @model.new
    @item.attributes = get_params

    if params[:commit] == I18n.t('ss.buttons.draft_save')
      notice = nil
      resp = @item.save_draft
    else
      notice = t('ss.notice.sent')
      resp = @item.send_mail
    end

    @item.destroy_files
    render_create resp, notice: notice
  end

  def destroy
    @imap.uids_move_trash [@item.uid]
    render_destroy true
  end

  def set_seen
    @imap.uids_set_seen get_uids
    render_change :set_seen, reload: true
  end

  def unset_seen
    @imap.uids_unset_seen get_uids
    render_change :unset_seen, reload: true
  end

  def set_star
    @imap.uids_set_star get_uids
    render_change :set_star, redirect: { action: :show }
  end

  def unset_star
    @imap.uids_unset_star get_uids
    render_change :unset_star, redirect: { action: :show }
  end

  def send_mdn
    if SS.config.webmail.store_mails
      @item = @imap.mails.find_and_store params[:id], :rfc822
    else
      @item = @imap.mails.find params[:id], :rfc822
    end
    @item.imap = @imap
    @item.send_mdn
    @imap.uids_set_mdn_sent get_uids

    render_change :send_mdn, redirect: { action: :show }
  end

  def ignore_mdn
    @imap.uids_set_mdn_sent get_uids
    render_change :ignore_mdn, redirect: { action: :show }
  end

  def copy
    @imap.uids_copy get_uids, params[:dst]
    render_change :copy, reload: true
  end

  def move
    @imap.uids_move get_uids, params[:dst]
    render_change :move, reload: true
  end

  def rename_mailbox
    @item = Webmail::Mailbox.where(original_name: params[:src]).first
    @item.name = Net::IMAP.decode_utf7(params[:dst])
    @item.imap = @imap
    @item.sync = true
    @item.update
    render_change :move, reload: true
  end

  def destroy_all
    @imap.uids_move_trash get_uids
    render_change :delete, reload: true
  end

  def empty
    @imap.uids_move_trash @imap.mails.mailbox(@mailbox).uids
    render_change :empty, reload: true
  end

  def render_change(action, opts = {})
    @imap.mailboxes.update_status if opts[:reload]

    location = params[:redirect].presence || opts[:redirect] || { action: :index }

    respond_to do |format|
      format.html { redirect_to location, notice: t("webmail.notice.#{action}") }
      format.json { render json: { action: params[:action], notice: t("webmail.notice.#{action}") } }
    end
  end
end
