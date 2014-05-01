
require 'logger'
require 'sinatra'
require 'mongo'
include Mongo

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

mongoHost='localhost'
mongoPort='27017'
mongoDb='islandora_redirect'
mongoColl='objects'
MONGO_ENABLED = false

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

  # @todo Refactor
  unless params.has_key? 'CISOROOT'

    redirect "http://digital.lafayette.edu/collections", 302
  end
  cdm_collection_alias = params[:CISOROOT].split('/').last

  # @todo Refactor
  redirect_uri = "http://digital.lafayette.edu/collections/#{islandora_collection_alias(cdm_collection_alias)}"
  unless params.has_key? 'CISOPTR'

    redirect redirect_uri, 302
  end

  cdm_object_id = params[:CISOPTR]

  if CDM_COLL_ALIASES.include? cdm_collection_alias

    redirect "http://cdm.lafayette.edu/cdm4/document.php?CISOROOT=/#{cdm_collection_alias}&CISOPTR=#{cdm_object_id}", 302
  end
end

get '/cdm4/item_viewer.php' do

  if not params.has_key? 'CISOROOT'

    redirect "http://digital.lafayette.edu/collections", 302
  end

  # Not decoding?
  cdm_collection_alias = params[:CISOROOT].split('2F').last
  cdm_collection_alias = params[:CISOROOT].split('/').last

  redirect_uri = "http://digital.lafayette.edu/collections/#{islandora_collection_alias(cdm_collection_alias)}"

  if not params.has_key? 'CISOPTR'

    redirect redirect_uri, 302
  end
  cdm_object_id = params[:CISOPTR]

  if CDM_COLL_ALIASES.include? cdm_collection_alias

    # redirect "http://cdm.lafayette.edu/cdm4/item_viewer.php?CISOROOT=/#{cdm_collection_alias}&CISOPTR=#{cdm_object_id}&CISOBOX=1", 302
    redirect "http://cdm.lafayette.edu", 302
  end

  # Caching
  mongo_doc = nil
  if MONGO_ENABLED

    @mongo = MongoClient.new(mongoHost, mongoPort)[mongoDb][mongoColl]
    mongo_doc = @mongo.find_one(:cdmColl => cdm_collection_alias, :cdmId => cdm_object_id)
  end
  if mongo_doc

    redirect_uri = "http://digital.lafayette.edu/#{mongo_doc['islandoraPathAlias']}"
  else

    redirect_uri = "http://digital.lafayette.edu/collections/#{islandora_collection_alias(cdm_collection_alias)}"

=begin
    agent = Mechanize.new
    agent.get 'http://cdm.lafayette.edu/cdm4/item_viewer.php', {:CISOROOT => '/' + cdm_collection_alias, :CISOPTR => cdm_object_id} do |page|

      metadb_url = page.links_with(:href => /metadb\.lafayette\.edu/).first.href

      islandora_object_alias = metadb_url.split('?item=').last

      # Remove additional digit for MetaDB identifiers
      islandora_object_alias.sub!(/0(\d{4})$/, '\1')

      # Cases for Object members of the Historical Photograph Collection
      if cdm_collection_alias == 'cap'

        islandora_object_alias.sub!('cap', 'hpc')
      end

      islandora_path_alias = "collections/#{islandora_collection_alias(cdm_collection_alias, :object_alias => islandora_object_alias)}"
      @mongo.insert(:cdmColl => cdm_collection_alias, :cdmId => cdm_object_id, :islandoraPathAlias => islandora_path_alias) if MONGO_ENABLED

      redirect_uri = "http://digital.lafayette.edu/#{islandora_path_alias}"
    end
=end
  end

  redirect redirect_uri, 301
end
