require 'sinatra'
require 'mongo'
require 'uri'

def get_connection
	return @db_collection if @db_collection
	db = URI.parse(ENV['MONGOHQ_URL'])
	db_name = db.path.gsub(/^\//, '')
	db_connection = Mongo::MongoClient.new(db.host, db.port).db(db_name)
	db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.password.nil?)
	@db_collection = db_connection.collection("rpg_exercise")
	return @db_collection
end

get '/' do
	#{}"Hello, world"
	#String.try_convert(ENV["MONGOHQ_URL"])
	String.try_convert(get_connection)
end

get '/:quiz' do
	"you are at #{params[:quiz]}"
end

get '/:quiz/:question' do
	"you are at #{params[:quiz]} in #{params[:question]}"
end