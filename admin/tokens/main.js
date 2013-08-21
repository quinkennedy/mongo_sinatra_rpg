//SITE = "http://localhost:5000";
SITE = "http://evening-castle-8558.herokuapp.com";

var whenReady = function(){
	t_listTemplate = Handlebars.compile(document.getElementById( 'token_list' ).textContent);
	t_indivTemplate = Handlebars.compile(document.getElementById( 'token_info' ).textContent);

	getList();
	console.log("loaded");
}

var getList = function(){
	$.ajax({ url: SITE+"/admin/token"
		, error: qError
		, success: gotTokens
		, dataType: "json"
		, type: "GET"/*"POST" "PUT" "DELETE"*/});
}

var gotTokens = function(data, textStatus, jqXHR){
	console.log(data);
	if (data.success){
		document.body.innerHTML = t_listTemplate(data);
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
	if (id.indexOf("t_") == 0){
		$.ajax({ url: SITE+"/admin/token/"+evt.target.id.substr(2)
			, error: qError
			, success: gotToken
			, dataType: "json"
			, type: "GET"});
	} else if (id == "close"){
		getList();
	} else if (id == "new"){
		showNewForm();
	} else if (id.indexOf("delete_") == 0){
		$.ajax({url: SITE+"/admin/token/"+evt.target.id.substr("delete_".length)
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
	document.body.innerHTML = t_indivTemplate({"new":true});
	$(".clickable").on("click", clicked);
}

var submitForm = function(uuid){
	$.ajax({url: SITE+"/admin/token"+(uuid ? "/" + uuid : "")
		, data: {text: $("#text").val()}
		, error: qError
		, success: function(data){console.log(data); getList()}
		, dataType: "json"
		, type: (uuid ? "PUT" : "POST")});
}

var gotToken = function(data, textStatus, jqXHR){
	console.log(data);
	document.body.innerHTML = t_indivTemplate(data);
	$(".clickable").on("click", clicked);
}

$(whenReady);