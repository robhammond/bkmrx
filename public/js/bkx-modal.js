
/* Functions for Modal popup window */

$(function() {
	$( "#submiturl_2" ).find('input.tag').tagedit({
		// return, comma, space, period, semicolon
		breakKeyCodes: [ 13, 44, 32, 46, 59 ],
		tabIndex: 3
	});
});

$(function() {
    $('.modal-footer').button();
    $('#bkx-modal').click(function() { $('input#step1url').focus(); });

	// Disabling enter key for now - causes more problems than it's worth
	$('input#step1url').keydown(function(event) {
		if (event.keyCode == 13) {
			event.preventDefault;
			return false;
		}
	});

    $("#step1sub").click(function suburl() {
		$('.loading').show();
		$('#step1sub').button('loading');
		$('.error').hide();  
		var urlsub = $("input#step1url").val();
	        if (urlsub == "") {  
	      $("label#urlsub_error").show();
	      $("input#step1sub").focus();  
	      return false;  
	    }
 
    	$.ajax({  
    	  type: "GET",  
    	  url: "/ajax/fetch_url",
    	  dataType: "json",
    	  data: 'url=' + urlsub,
    	  success: function(result) {  
    		
    		$('input#title').val(result.title);
    		$('textarea#desc').text(result.metad);
    		
    		if (result.status == 'error') {
    			$('h6#url_msg').append("There was an error fetching your URL");
    		}
    		if (result.url != result.orig_url) {
    			$('h6#url_msg').append("Your URL was redirected. You can choose the original or the redirected URL below");
    			$('div#callback').append("<select name='url'><option selected>" + 
    									result.url + '</option><option>' +
    									result.orig_url + '</option></select>');
    		} else {
    			$('h5#ret_url').append(result.url);
    			$('div#callback').append('<input type="hidden" name="url" value="' + result.url + '" />');
    		}
    		
      	    $('form#submiturl').hide();
      	    $('div#urlform2').show();
      	    $(':button#step1sub').hide();
      	    $(':button#step2sub').show();
    	  },
    	});  
    	return false;  
    });

	$("#step2sub").click(function() {
		$("#submiturl_2").submit();
	});
});