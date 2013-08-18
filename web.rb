require 'sinatra'
require 'mongo'
require 'uri'
require 'json'

$QUESTIONS = "questions"
$ROUNDS = "rounds"
$TOKENS = "tokens"
$db_collection = {}

def get_collection(coll_name)
	return $db_collection[coll_name] if $db_collection[coll_name]
	db = URI.parse(ENV['MONGOHQ_URL'])
	db_name = db.path.gsub(/^\//, '')
	db_connection = Mongo::MongoClient.new(db.host, db.port).db(db_name)
	db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.password.nil?)
	$db_collection[coll_name] = db_connection.collection("#{ENV["COLL_PREFIX"]}#{coll_name}")
	return $db_collection[coll_name]
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
	response = {"result" => "", "success" => false, "error" => "unknown"}
	question = get_collection($QUESTIONS).find("uuid" => uuid)
	if question
		response["result"] = question.to_a
		response["success"] = true
	else
		response["error"] = "invalid id"
	end

	if response["success"]
		response["error"] = ""
	end
	response
end

get '/admin/question' do
	#get list of questions

	#return get /admin/question/page/0
	status, headers, body = call env.merge("PATH_INFO" => "/admin/question/page/0")
  [status, headers, body.map(&:upcase)]
end

get %r{/admin/question/page/([\d]+)} do |n|
	#get page-inated list of questions in groups of 10
	#TODO: have group size configurable with max limit and default
	coll = get_collection($QUESTIONS)
	i = 0;
	n = Integer(n)
	response = {"result" => "", "success" => false, "error" => "unknown"}
	coll.find.each_slice(10) do |slice|
		if i == n
			response["result"] = slice.to_a
			response["success"] = true
			break
		end
		i += 1
	end
	if i != n
		response["error"] = "not that many questions"
	elsif response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

post '/admin/question' do
	#create a new question
	response = {"result" => "", "success" => false, "error" => "unknown"}
	
	#check that there is text
	text = params["text"]
	if text
		text = text.strip
		if text != ""
			#make sure text is unique
			questions = get_collection($QUESTIONS)
			if questions.find("text" => text).count == 0
				#TODO: handle token definitions
				#get (and confirm) a unique id
				uuid = ""
				begin
					uuid = `uuidgen`.strip
				end until questions.find("uuid" => uuid).count == 0

				question = {"uuid" => uuid, "text" => params["text"], "tokens" => {}}
				question["_id"] = questions.insert(question)
				response["result"] = question
				response["success"] = true
			else
				response["error"] = "duplicate question text found"
				# TODO: include duplicate question uuid?
			end
		else
			response["error"] = "no question text provided"
		end
	else
		response["error"] = "no question text provided"
	end

	if response["success"]
		response["error"] = ""
	end
	content_type :json
	response.to_json
end

get '/admin/question/:id' do |id|
	#get the specific question
	content_type :json
	response = adminGetQuestion(id).to_json
end

put '/admin/question/:id' do |id|
	#update the specific question
	response = adminGetQuestion(id)
	if response["sucess"]
		response["success"] = false
		response["error"] = "unknown"
		question = response["result"][0]

		#do update
		updated = false;
		text = params["text"]
		if text
			text = text.strip
			if text != "" and text != question["text"]
				question["text"] = text
				updated = true;
			end
		end
		#TODO: update tokens

		if updated
			get_collection($QUESTIONS).update({"_id" => question["_id"]}, question)
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

delete '/admin/question/:id' do |id|
	#delete the specific question
	response = {"result" => "", "success" => false, "error" => "unknown"}
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
                                            
get %r{/admin/token/page/([\d]+)} do |n|
	#get page-inated list of questions in groups of 10
	#TODO: have group size configurable with max limit and default
	coll = get_collection($TOKENS)
	i = 0;
	coll.find.each_slice(10) do |slice|
		if i == n
			slice.to_a
			break
		end
		i += 1
	end
	if i != n
		"past end"
	end
end

post '/admin/token' do
	#create a new token
	# TODO: check that there is text
	# TODO: check that the text does not match an existing token
	# TODO: handle token definitions
	uuid = `uuidgen`.strip
	token = {"uuid" => uuid, "text" => params["text"]}
	id = get_collection($TOKENS).insert(token)
	#return get /admin/token/#{id}
	token["id"] = id
	"did it"
end

get '/admin/token/:id' do
	#get the specific token
end

put '/admin/token/:id' do
	#update the specific token
end

delete '/admin/token/:id' do
	#delete the specific token
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
