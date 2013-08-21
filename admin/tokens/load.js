//including custom css-loading function
//because requirejs does not support loading css
function loadCSS(url){
    var link = document.createElement("link");
    link.type = "text/css";
    link.rel = "stylesheet";
    link.href = url;
    document.getElementsByTagName("head")[0].appendChild(link);
}

loadCSS("../../css/bootstrap.min.css");

require(["../../js/jquery.2.0.2.min.js"
	, "../../js/tween.r10.min.js"
	, "../../js/handlebar.1.0.0.js"], function(){
	require(["main"]);
});