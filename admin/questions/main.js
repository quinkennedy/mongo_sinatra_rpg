//SITE = "http://localhost:5000";
SITE = "http://evening-castle-8558.herokuapp.com";
currPage = 0;
tokens = undefined;

var whenReady = function(){
	q_listTemplate = Handlebars.compile(document.getElementById( 'question_list' ).textContent);
	q_indivTemplate = Handlebars.compile(document.getElementById( 'question_info' ).textContent);

	getList();
	console.log("loaded");
}

//will call callback and pass in the tokens
var getTokens = function(callback){
	if (tokens){
		callback(tokens)
	} else {
		$.ajax({ url: SITE+"/admin/token"
			, error: qError
			, success: function(data, textStatus, jqXHR){
				console.log(data);
				if (!data.success){
					document.body.innerHTML = "error while retrieving tokens: " + data.error;
				} else {
					tokens = data.result.tokens;
					callback(tokens);
				}
			}
			, dataType: "json"
			, type: "GET"});
	}
}

var getList = function(page){
	page |= currPage;
	$.ajax({ url: SITE+"/admin/question/page/"+page
		, error: qError
		, success: gotQuestions
		, dataType: "json"
		, type: "GET"/*"POST" "PUT" "DELETE"*/});
}

var gotQuestions = function(data, textStatus, jqXHR){
	console.log(data);
	if (data.success){
		currPage = data.result.page;
		if (currPage > 0){
			data.result.showPrev = true;
		}
		if (currPage < data.result.num_pages - 1){
			data.result.showNext = true;
		}
		document.body.innerHTML = q_listTemplate(data);
		$(".clickable").on("click", clicked);
	} else {
		document.body.innerHTML = "error: " + data.error;
	}
}

var qError = function(){
	console.error("error");
}

var clicked = function(evt){
	var id = evt.target.id;
	if (id.indexOf("q_") == 0){
		$.ajax({ url: SITE+"/admin/question/"+evt.target.id.substr(2)
			, error: qError
			, success: gotQuestion
			, dataType: "json"
			, type: "GET"});
	} else if (id == "close"){
		getList(currPage);
	} else if (id == "next"){
		getList(currPage + 1);
	} else if (id == "prev"){
		getList(currPage - 1);
	} else if (id == "new"){
		showNewForm();
	} else if (id.indexOf("delete_") == 0){
		$.ajax({url: SITE+"/admin/question/"+evt.target.id.substr("delete_".length)
			, error: qError
			, success: function(){getList();}
			, dataType: "json"
			, type: "DELETE"});
	} else if (id.indexOf("update_") == 0){
		if ($(this).text() == "edit"){
			$("[readonly]").removeAttr("readonly").removeAttr("disabled");
			$(this).text("update");
			$(this).addClass("btn-warning");
			$(this).removeClass("btn-default");
		} else {
			submitForm(id.substr("update_".length));
		}
	}
}

var showNewForm = function(){
	getTokens(function(tokens){
		var data = {tokens:tokens, new:true};
		document.body.innerHTML = q_indivTemplate(data);
		$(".clickable").on("click", clicked);
	});
}

var submitForm = function(uuid){
	var data = {text: $("#text").val()};
	$("input").each(function(index, element){
		if (this.id.indexOf("i_") == 0){
			//this is an input
			data[this.id.substr(2)] = $(this).val();
		}
	});
	console.log(data);

	$.ajax({url: SITE+"/admin/question"+(uuid ? "/" + uuid : "")
		, data: data
		, error: qError
		, success: function(data){console.log(data); getList(currPage)}
		, dataType: "json"
		, type: (uuid ? "PUT" : "POST")});
}

var gotQuestion = function(data, textStatus, jqXHR){
	console.log(data);
	data.tokens = data.result.questions[0].tokens;
	document.body.innerHTML = q_indivTemplate(data);
	$(".clickable").on("click", clicked);
	// getTokens(function(tokens){
	// 	data.tokens = tokens;
	// 	document.body.innerHTML = q_indivTemplate(data);
	// 	$(".clickable").on("click", clicked);
	// });
}

$(whenReady);