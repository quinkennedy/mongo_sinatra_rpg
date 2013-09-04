require 'sinatra'
require 'mongo'
require 'uri'
require 'json'
require 'sinatra/cross_origin'
require 'uuid'

$QUESTIONS = "questions"
$ROUNDS = "rounds"
$TOKENS = "tokens"
$db_collection = {}
$uuid = UUID.new

def get_collection(coll_name)
	return $db_collection[coll_name] if $db_collection[coll_name]
	db = URI.parse(ENV['MONGOHQ_URL'])
	db_name = db.path.gsub(/^\//, '')
	db_connection = Mongo::MongoClient.new(db.host, db.port).db(db_name)
	db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.password.nil?)
	$db_collection[coll_name] = db_connection.collection("#{ENV["COLL_PREFIX"]}#{coll_name}")
	return $db_collection[coll_name]
end

configure do
	enable :cross_origin
	set :allow_methods, [:get, :post, :options, :delete, :put]

#http://stackoverflow.com/questions/4351904/sinatra-options-http-verb
	class << Sinatra::Base
    def options(path, opts={}, &block)
      route 'OPTIONS', path, opts, &block
    end
  end
  Sinatra::Delegator.delegate :options
end

#Admin Questions
    #                                                      
   # #   #####  #    # # #    #                            
  #   #  #    # ##  ## # ##   #                            
 #     # #    # # ## # # # #  #                            
 ####### #    # #    # # #  # #                            
 #     # #    # #    # # #   ##                            
 #     # #####  #    # # #    #                            
                                                           
  #####                                                    
 #     # #    # ######  ####  ##### #  ####  #    #  ####  
 #     # #    # #      #        #   # #    # ##   # #      
 #     # #    # #####   ####    #   # #    # # #  #  ####  
 #   # # #    # #           #   #   # #    # #  # #      # 
 #    #  #    # #      #    #   #   # #    # #   ## #    # 
  #### #  ####  ######  ####    #   #  ####  #    #  ####

def adminGetQuestion(uuid)
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	question = get_collection($QUESTIONS).find("uuid" => uuid)
	if question
		response["result"]["questions"] = question.to_a
		response["success"] = true
	else
		response["error"] = "invalid id"
	end

	if response["success"]
		response["error"] = ""
	end
	response
end

# get '/admin/question' do
# 	#get list of questions

# 	#return get /admin/question/page/0
# 	status, headers, body = call env.merge("PATH_INFO" => "/admin/question/page/0")
#   [status, headers, body.map(&:upcase)]
# end

get %r{/admin/question/page/([\d]+)} do |n|
	#get page-inated list of questions in groups of 10
	#TODO: have group size configurable with max limit and default
	coll = get_collection($QUESTIONS)
	i = 0;
	n = Integer(n)
	questions = coll.find
	numPages = (questions.count + 9) / 10
	response = {"result" => {"page" => n, "questions" => [], "num_pages" => numPages}, "success" => false, "error" => "unknown"}

	#TODO: use numPages to skip this if possible
	questions.each_slice(10) do |slice|
		if i == n
			response["result"]["questions"] = slice.to_a
			response["success"] = true
			break
		end
		i += 1
	end

	if i != n
		response["error"] = "not that many questions"
		response["result"]["num_pages"] = i
	elsif response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

def getQTokens(params)
	qTokens = {}
	tokens = adminGetTokens
	tokens.each_slice(10) do |slice|
		slice.each do |token|
			tokenData = {}
			hasData = false
			begin
				value = Integer(params[token["uuid"]+"_yes"].strip);
				if value != 0
					tokenData["yes"] = value
					hasData = true
				end
			rescue Exception
			end
			begin
				value = Integer(params[token["uuid"]+"_no"].strip);
				if value != 0
					tokenData["no"] = value
					hasData = true
				end
			rescue Exception
			end
				if hasData
					qTokens[token["uuid"]] = tokenData
				end
		end
	end
	qTokens
end

post '/admin/question' do
	#create a new question
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	
	#check that there is text
	text = params["text"]
	if text and text.is_a? String
		text = text.strip
		if text != ""
			#make sure text is unique
			questions = get_collection($QUESTIONS)
			if questions.find("text" => text).count == 0
				#handle token definitions
				qTokens = getQTokens(params)

				#get (and confirm) a unique id
				#TODO: db query might be more expensive than generating a uuid,
				#  if so, we should gen the uuid before the first query
				uuid = ""
				begin
					uuid = $uuid.generate
				end until questions.find("uuid" => uuid).count == 0

				question = {"uuid" => uuid, "text" => params["text"], "tokens" => qTokens}
				question["_id"] = questions.insert(question)
				response["result"]["questions"] = [question]
				response["success"] = true
			else
				response["error"] = "duplicate question text found"
				# TODO: include duplicate question uuid?
			end
		else
			response["error"] = "no text provided"
		end
	else
		response["error"] = "no text provided"
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

get '/admin/question/:id' do |id|
	#get the specific question
	response = adminGetQuestion(id)
	puts response.to_json
	if response["success"]
		#move tokens to array and
		#  add all other tokens to 0
		tokens = adminGetTokens
		qTokens = response["result"]["questions"][0]["tokens"]
		response["result"]["questions"][0]["tokens"] = []
		tokens.each_slice(10) do |slice|
			slice.each do |token|
				value = {"yes" => 0, "no" => 0}
				if qTokens[token["uuid"]] and qTokens[token["uuid"]]["yes"]
					value["yes"] = qTokens[token["uuid"]]["yes"]
				end
				noValue = 0
				if qTokens[token["uuid"]] and qTokens[token["uuid"]]["no"]
					value["no"] = qTokens[token["uuid"]]["no"]
				end
				response["result"]["questions"][0]["tokens"].push({"uuid" => token["uuid"], "text" => token["text"], "value" => value})
			end
		end
	end

	content_type :json
	response.to_json
end

options '/admin/question/:id' do
end

put '/admin/question/:id' do |id|
	#update the specific question
	response = adminGetQuestion(id)
	if response["success"]
		response["success"] = false
		response["error"] = "unknown"
		question = response["result"]["questions"][0]
		questions = get_collection($QUESTIONS)

		#do update
		# TODO: make sure the text is still unique
		updated = false
		error = false
		text = params["text"]
		if text and text.is_a? String
			text = text.strip
			if text != "" and text != question["text"]
				if questions.find("text" => text).count == 0
					question["text"] = text
					updated = true;
				else
					error = true
					response["error"] = "duplicate question text found"
				end
			end
		end
		
		#update tokens
		puts question.to_json
		unless error
			#TODO: check if tokens have changed to avoid unnecessary update
			question["tokens"] = getQTokens(params)
			updated = true;
		end
		puts question.to_json

		if updated
			questions.save(question)
			response["success"] = true
		elsif !error
			response["error"] = "no update"
		end
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

delete '/admin/question/:id' do |id|
	#delete the specific question
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	questions = get_collection($QUESTIONS)
	oldCount = questions.count
	questions.remove("uuid" => id)
	newCount = questions.count
	if oldCount != newCount
		response["result"] = {"questions_remaining" => newCount}
		response["success"] = true
	else
		response["error"] = "invalid id"
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end


#Admin Tokens
    #                                       
   # #   #####  #    # # #    #             
  #   #  #    # ##  ## # ##   #             
 #     # #    # # ## # # # #  #             
 ####### #    # #    # # #  # #             
 #     # #    # #    # # #   ##             
 #     # #####  #    # # #    #             
                                            
 #######                                    
    #     ####  #    # ###### #    #  ####  
    #    #    # #   #  #      ##   # #      
    #    #    # ####   #####  # #  #  ####  
    #    #    # #  #   #      #  # #      # 
    #    #    # #   #  #      #   ## #    # 
    #     ####  #    # ###### #    #  ####  

def adminGetToken(uuid)
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	token = get_collection($TOKENS).find("uuid" => uuid)
	if token
		response["result"]["tokens"] = token.to_a
		response["success"] = true
	else
		response["error"] = "invalid id"
	end

	if response["success"]
		response["error"] = ""
	end
	response
end

def adminGetTokens
	#TODO: is there a safe way to cache all the tokens
	#  , and update when new tokens are added?
	get_collection($TOKENS).find({}, :fields => ["uuid", "text"])
end

get '/admin/token' do
	#get list of all tokens
	coll = get_collection($TOKENS)

	response = {"result" => {"tokens" => adminGetTokens.to_a}, "success" => false, "error" => "unknown"}
	response["success"] = true

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

post '/admin/token' do
	#create a new token
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	
	#check that there is text
	text = params["text"]
	if text and text.is_a? String
		text = text.strip
		if text != ""
			#make sure text is unique
			tokens = get_collection($TOKENS)
			if tokens.find("text" => text).count == 0
				#get (and confirm) a unique id
				uuid = ""
				begin
					uuid = $uuid.generate
				end until tokens.find("uuid" => uuid).count == 0

				token = {"uuid" => uuid, "text" => params["text"]}
				token["_id"] = tokens.insert(token)
				response["result"]["tokens"] = [token]
				response["success"] = true
			else
				response["error"] = "duplicate token text found"
				# TODO: include duplicate token uuid?
			end
		else
			response["error"] = "no text provided"
		end
	else
		response["error"] = "no text provided"
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

get '/admin/token/:id' do |id|
	#get the specific token
	content_type :json
	response = adminGetToken(id).to_json
end

options '/admin/token/:id' do
end

put '/admin/token/:id' do |id|
	#update the specific token
	response = adminGetToken(id)
	if response["success"]
		response["success"] = false
		response["error"] = "unknown"
		token = response["result"]["tokens"][0]

		#do update
		# TODO: make sure the text is still unique
		updated = false;
		text = params["text"]
		if text and text.is_a? String
			text = text.strip
			if text != "" and text != token["text"]
				token["text"] = text
				updated = true;
			end
		end

		if updated
			get_collection($TOKENS).update({"uuid" => token["uuid"]}, token)
			response["success"] = true
		else
			response["error"] = "no update"
		end
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

delete '/admin/token/:id' do |id|
	#delete the specific token
	response = {"result" => {}, "success" => false, "error" => "unknown"}
	tokens = get_collection($TOKENS)
	oldCount = tokens.count
	tokens.remove("uuid" => id)
	newCount = tokens.count
	if oldCount != newCount
		response["result"] = {"tokens_remaining" => newCount}
		response["success"] = true
	else
		response["error"] = "invalid id"
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

#Rounds
 ######                                     
 #     #  ####  #    # #    # #####   ####  
 #     # #    # #    # ##   # #    # #      
 ######  #    # #    # # #  # #    #  ####  
 #   #   #    # #    # #  # # #    #      # 
 #    #  #    # #    # #   ## #    # #    # 
 #     #  ####   ####  #    # #####   ####  
                                            
post '/round' do
	#create new round
end

put '/round/:id' do
	#
end

get '/round/:id' do
end
