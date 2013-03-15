(function(){

	var v = "1.8.0";

	if (window.jQuery === undefined || window.jQuery.fn.jquery < v) {
		var done = false;
		var script = document.createElement("script");
		//script.src = "http://ajax.googleapis.com/ajax/libs/jquery/" + v + "/jquery.min.js";
		script.src = "http://dev.bkmrx.com/js/jquery-1.8.0.min.js";
		script.onload = script.onreadystatechange = function(){
			if (!done && (!this.readyState || this.readyState == "loaded" || this.readyState == "complete")) {
				done = true;
				initBkxMrk();
			}
		};
		document.getElementsByTagName("head")[0].appendChild(script);
	} else {
		initBkxMrk();
	}
	
	function initBkxMrk() {
		(window.bkxMrk = function() {
			function getSelText() {
				var s = '';
				if (window.getSelection) {
					s = window.getSelection();
				} else if (document.getSelection) {
					s = document.getSelection();
				} else if (document.selection) {
					s = document.selection.createRange().text;
				}
				return s;
			}
			if ($("#bkxframe").length == 0) {
				var s = "";
				var title = document.title;
				var url   = document.location;
				s = getSelText();
				
				if ((url != "") && (url != null)) {
					$("body").append("\
					<div id='bkxframe'>\
						<div id='bkxframe_veil' style=''>\
							<p>Loading...</p>\
						</div>\
						<iframe src='http://dev.bkmrx.com/bklet?url="+url+"&title="+title+"&desc="+s+"' onload=\"$('#bkxframe iframe').slideDown(500);\">Enable iFrames.</iframe>\
						<style type='text/css'>\
							#bkxframe_veil { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background-color: rgba(255,255,255,.25); z-index: 900; }\
							#bkxframe_veil p { color: black; font: normal normal bold 20px/20px Helvetica, sans-serif; position: absolute; top: 50%; left: 50%; width: 10em; margin: -10px auto 0 -5em; text-align: center; }\
							#bkxframe iframe { display: none; position: fixed; top: 10%; left: 10%; width: 600px; height: 450px; z-index: 999; border: 10px solid rgba(0,0,0,.5); margin: -5px 0 0 -5px; }\
						</style>\
					</div>");
					$("#bkxframe_veil").fadeIn(750);
				}
			} else {
				$("#bkxframe_veil").fadeOut(750);
				$("#bkxframe iframe").slideUp(500);
				setTimeout("$('#bkxframe').remove()", 750);
			}
			$("#bkxframe_veil").click(function(event){
				$("#bkxframe_veil").fadeOut(750);
				$("#bkxframe iframe").slideUp(500);
				setTimeout("$('#bkxframe').remove()", 750);
			});
		})();
	}

})();