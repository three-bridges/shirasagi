namespace :opendata do
  task import_datasets: :environment do
    ::Tasks::Cms.each_sites do |site|
      if ENV.key?("node")
        ::Tasks::Cms.with_node(site, ENV["node"]) do |node|
          ::Tasks::Cms.perform_job(::Opendata::ImportDatasetJob, site: site, node: node)
        end
      else
        ::Tasks::Cms.perform_job(::Opendata::ImportDatasetJob, site: site)
      end
    end
  end
end
