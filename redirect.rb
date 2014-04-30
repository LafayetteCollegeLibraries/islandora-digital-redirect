
require 'logger'
require 'sinatra'
require 'mongo'
include Mongo

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

mongoHost='139.147.4.144'
mongoPort='27017'
mongoDb='islandora_redirect'
mongoColl='objects'

require 'mechanize'

configure do
  set :port, '4568'

  # http://stackoverflow.com/a/17335819
  set :server, 'webrick'
end

CDM_ISLANDORA_EASTASIA_MAP = {

  'ia' => 'pa-koshitsu',
  'sv' => 'rjw-stereo',
  'ip' => 'imperial-postcards',
  'rj' => 'pa-tsubokura',
  'oa' => 'pa-omitsu01',
  'ob' => 'pa-omitsu02',
  'cf' => 'lin-postcards',
  'fc' => 'gc-iroha01',
  'fd' => 'pacwar-postcards',
  'lw' => 'lewis-postcards',
  'wa' => 'warner-postcards',
  'in' => 'warner-negs-indonesia',
  'db' => 'warner-negs-manchuria',
  'gr' => 'warner-negs-taiwan',
  'js' => 'warner-slides-japan',
  'ac' => 'warner-souvenirs',
  'ww' => 'woodsworth-images',
  'nf' => 'cpw-nofuko',
  'ts' => 'cpw-shashinkai',
}

CDM_ISLANDORA_COLL_MAP = {
  'eastasia' => 'eastasia',
  'mdl-prints' => 'lafayetteprints',
  'cap' => 'historicalphotos',
  'war-casualties' => 'war',
  'mckelvy' => 'mckelvy',
  'geology' => 'geology',
}

CDM_COLL_ALIASES = ['newspaper', 'presidents']

def islandora_collection_alias(cdm_alias, object_alias: nil)

  if cdm_alias == 'eastasia' and object_alias

    m = /(.+?)\-(\d+)/.match(object_alias)
    object_prefix = m[1]
    object_index = m[2]

    return "eastasia/#{object_prefix}/#{CDM_ISLANDORA_EASTASIA_MAP.invert[object_prefix] + object_index}"
  else

    return "#{CDM_ISLANDORA_COLL_MAP[cdm_alias]}/#{object_alias}"
  end
end

get '/cdm4/document.php' do

  cdm_collection_alias = params[:CISOROOT].sub('/', '')
  cdm_object_id = params[:CISOPTR]

  if CDM_COLL_ALIASES.include? cdm_collection_alias

    redirect "http://cdm.lafayette.edu/cdm4/document.php?CISOROOT=/#{cdm_collection_alias}&CISOPTR=#{cdm_object_id}", 302
  end
end

get '/cdm4/item_viewer.php' do

  cdm_collection_alias = params[:CISOROOT].sub('/', '')
  cdm_object_id = params[:CISOPTR]

  if CDM_COLL_ALIASES.include? cdm_collection_alias

    redirect "http://cdm.lafayette.edu/cdm4/item_viewer.php?CISOROOT=/#{cdm_collection_alias}&CISOPTR=#{cdm_object_id}&CISOBOX=1", 302
  end

  redirect_uri = "http://digital.lafayette.edu/collections/#{islandora_collection_alias(cdm_collection_alias)}/browse"

  # Caching
  @mongo = MongoClient.new(mongoHost, mongoPort)[mongoDb][mongoColl]
  mongo_doc = @mongo.find_one(:cdmColl => cdm_collection_alias, :cdmId => cdm_object_id)
  if mongo_doc

    redirect_uri = "http://digital.lafayette.edu/#{mongo_doc['islandoraPathAlias']}"
  else

    agent = Mechanize.new
    agent.get 'http://cdm.lafayette.edu/cdm4/item_viewer.php', params do |page|

      metadb_url = page.links_with(:href => /metadb\.lafayette\.edu/).first.href

      islandora_object_alias = metadb_url.split('?item=').last

      # Remove additional digit for MetaDB identifiers
      islandora_object_alias.sub!(/0(\d{4})$/, '\1')

      # Cases for Object members of the Historical Photograph Collection
      if cdm_collection_alias == 'cap'

        islandora_object_alias.sub!('cap', 'hpc')
      end

      islandora_path_alias = "collections/#{islandora_collection_alias(cdm_collection_alias, :object_alias => islandora_object_alias)}"
      @mongo.insert(:cdmColl => cdm_collection_alias, :cdmId => cdm_object_id, :islandoraPathAlias => islandora_path_alias)

      redirect_uri = "http://digital.lafayette.edu/#{islandora_path_alias}"
    end
  end

  redirect redirect_uri, 301
end
