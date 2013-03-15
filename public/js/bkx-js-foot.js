 // Functions for Modal popup window */

/* Modal window */
$(document).ready(function() {
	$('[data-toggle="modal"]').click(function(e) {
		e.preventDefault();
		var href = $(this).attr('href');
		if (href.indexOf('#') == 0) {
			$(href).modal('open');
		} else {
			$('#bkx-modal').modal('show');
		    $('#bkx-modal').load(this.href);
		}
	});
});

/* End functions for modal popup window */

/* Update filter on bkmrx.php page */
$('#filter').keyup(function() {
	updateTags($('#filter').val());
});

function updateTags (tagname) {
	$.ajax({
		url: '/ajax/json_taglist',
		data: "filter=" + tagname,
		dataType: "json",
		type: 'POST',
		success: function(result) {
			var items = [];
			$.each(result, function(key, val) {
				var active = '';
				var close  = '';
				if (tagname == key) {
					active = ' class="active"';
					close  = ' <a href="/bkmrx">&times;</a>';
				}
				items.push('<li' + active + '><a href="?tag=' + key + '"><i class="icon-tag"></i>' + key + '</a> <sup>' + val + '</sup>' + close + '</li>');
			});
			$('#ajaxtags').html(items.join(''));
		}
	});
}
/* End update filter */



/* add tags function */
function add_tags() {
    $('.add_tag').editable('/ajax/add-tag', {
    	indicator   : '',
        tooltip     : 'Add a tag...',
        placeholder : '+tag',
        name : 'tag',
        width : '100',
        breakKeyCodes : [9, 13, 44, 32, 46, 59, 188],
        ajaxoptions : {success: function(result){
            				// weirdly need to eval result to get it as a json obj
            				var json = eval('(' + result + ')');
            				var b_id = json.b_id;
            				var tag  = json.tag;
            				$('div#d' + b_id).find("span#" + b_id).remove();
            				$('#added_tags_' + b_id).append("<span class='label label-info' style='margin:2px;' id='" 
            					+ tag + "-" + b_id 
            					+ "'><a href='?tag=" 
            					+ tag 
            					+ "' style='color:white'>" 
            					+ tag 
            					+ "</a> <a href='/ajax/delete-tag?tag=" 
            					+ tag 
            					+ "&amp;b_id=" 
            					+ b_id 
            					+ "' style='color:white;' class='deltag'>&times;</a></span><span class='add_tag' id='" 
            					+ b_id + "'></span>");
            				add_tags();
            		   }}
    });
}
/* end add tags function */

/* Functions for hovering lock icons on bkx page */

// ensure that ajax events happen on doc load as well as ajax refresh
$(document).ready(function(){
	initBinding();
});

function initBinding() {
	$('i.bkx-lock').on({
		click: function(){
			var b_id = $(this).attr('b_id');
			bkxLock(b_id, 'unlock');
		},
		mouseenter: function(){
			$(this).attr("class", "bkx-unlock icon-unlock");
		},
		mouseleave: function() {
			$(this).attr("class", "bkx-lock icon-lock");
		}
	});
	
	$('i.bkx-unlock').on({
		click: function(){
			var b_id = $(this).attr('b_id');
			bkxLock(b_id, 'lock');
		},
		mouseenter: function(){
			$(this).attr("class", "bkx-lock icon-lock");
		},
		mouseleave: function() {
			$(this).attr("class", "bkx-unlock icon-unlock");
		}
	});
	
}
function bkxLock(b_id, action) {
	$.ajax({
		url: '/ajax/lock-unlock',
		data: "b_id=" + b_id + "&action=" + action,
		dataType: "json",
		success: function() {
			// Now update the user interface
			$("i[b_id=" + b_id + "]").attr("class", "bkx-" + action + " icon-" + action);
			initBinding();
		}
	});
}
/* end locks */


/* delete tags from a page */
$('.deltag').click(function(e) {
    var answer = confirm("Are you sure you want to delete this tag?");
    var span_id = $(this).parent().attr('id');
    var tag  = span_id.replace(/-.*$/, '');
    var b_id = span_id.replace(/^[^-]+-/, '');
    if (answer){
        // do the default action
        e.preventDefault();
    	$.ajax({
    		url: '/ajax/delete-tag',
    		data: "tag=" + tag + "&b_id=" + b_id,
    		dataType: "html",
    		success: function(result) {
    			// Now update the user interface
    			$('span#' + span_id).remove();
    		}
    	});
    } else {
      e.preventDefault();
    }
});
/* end delete tags */

/* add bkmrk directly from SERP */
function addBkx (url_id, title) {
	$.ajax({
		url: '/ajax/serp-add',
		data: "url_id=" + url_id + "&title=" + title,
		dataType: "html",
		type: 'POST',
		success: function(result) {
			// below was rushed so need to fix
			$('button#' + url_id).addClass('btn-success');
			$('button#' + url_id).addClass('disabled');
			$('button#' + url_id).attr('disabled', 'disabled');
			$('button#' + url_id).removeClass('btn-primary');
			$('button#' + url_id).text('added!');
		}
	});
}
/* end SERP bookmarking */

/* edit bkmrx inline functions */

$('button.delbkmrk').click(function(e) {
    var answer = confirm("Are you sure you want to delete this bookmark?");
    var b_id   = $(this).attr('bkx');
    var added  = $('div.bkmrk[bkx="' + b_id + '"]').attr('added');
    if (answer){
        // do the default action
        e.preventDefault();
    	$.ajax({
    		url: '/ajax/delete-bkmrk',
    		data: "b_id=" + b_id,
    		dataType: "html",
    		success: function(result) {
    			var len = $('div.bkmrk[added="' + added + '"]').length;
    			// Remove date separator if there's only one added on that date
    			if (len == 1) {
    				$('div.bkmrk[bkx="' + b_id + '"]').prev('div.d').remove();
    			}
    			// Remove deleted bookmark from DOM
    			$('div.bkmrk[bkx="' + b_id + '"]').remove();
    		}
    	});
    } else {
      e.preventDefault();
    }
});
/* end edit bkmrx functions */

/* function for toggling editor on bkmrx page */
var placeholder_text = 'click wrench to edit';
$('span.desc').each(function() {
	if ($(this).text() == '') {
		$(this).html("<span style='color:gray;'>" + placeholder_text + "</span>");
	}
});
// $('span.desc').html('&laquo; click to edite!');
function bkxEditOn(bkx_id) {
	// Show all elements and add well class
	$('.bkx-jedit-hide[bkx="' + bkx_id + '"]').each(function(index) {
			$(this).attr("class", 'bkx-jedit-show')
		});
	$('.row-fluid[bkx="' + bkx_id + '"]').addClass("well");

	// change a bunch of classes
	$('div[bkx="' + bkx_id + '"] i.icon-wrench').attr("style", "color:orange");
	$('div#d' + bkx_id + ' h3 a').replaceWith("<span href='" + 
			$('div#d' + bkx_id + ' h3 a').attr('href') + 
			"' id='t_" + bkx_id +
			"'>" + 
			$('div#d' + bkx_id + ' h3 a').text() +
			"</span>");

	// save the title
	$('div#d' + bkx_id + ' h3 span').editable('/ajax/update-bkmrk', {
    	indicator : 'Saving...',
        tooltip   : 'Click to edit title...',
        placeholder : 'Click to edit title...',
        width     : 450,
        cancel    : 'Cancel',
        submit    : 'OK',
        name : 'title'
    });

	// save the description
	if ($('div#d' + bkx_id + ' .bkx-wrapper span.desc').text() == placeholder_text) {
		$('div#d' + bkx_id + ' .bkx-wrapper span.desc').html('');
	}
	
	$('div#d' + bkx_id + ' .bkx-wrapper span.desc').attr("id", "d_" + bkx_id);
	$('div#d' + bkx_id + ' .bkx-wrapper span#d_' + bkx_id).editable('/ajax/update-bkmrk', {
    	indicator : 'Saving...',
        tooltip   : 'Click to edit description...',
        placeholder : 'Click to edit description...',
        width     : 350,
        cancel    : 'Cancel',
        submit    : 'OK',
        name : 'desc'
    });
}

function bkxEditOff(bkx_id) {
	$('div[bkx="' + bkx_id + '"] i.icon-wrench').attr("style", "color:gray");
	// Change back to a href
	$('div#d' + bkx_id + ' h3 span').replaceWith("<a href='" + 
			$('div#d' + bkx_id + ' h3 span').attr('href') + 
			"'>" + 
			$('div#d' + bkx_id + ' h3 span').text() +
			"</a>");

	// Remove editable part from span
	$('div#d' + bkx_id + ' .bkx-wrapper span.desc').attr("id", "");

	$('.row-fluid[bkx="' + bkx_id + '"]').removeClass("well");
	$('.bkx-jedit-show[bkx="' + bkx_id + '"]').attr("class", 'bkx-jedit-hide');
}
/* end function */