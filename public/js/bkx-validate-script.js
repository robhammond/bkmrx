// 
//	jQuery Validate example script
//
//	Prepared by David Cochran
//	Modified by rob hammond
//	Free for your use -- No warranties, no guarantees!
//

$(document).ready(function(){
		$('#register-form').validate({
		    rules: {
		      username: {
		        minlength: 3,
		        required: true
		      },
		      email: {
		        required: true,
		        email: true
		      },
		      pass: {
		      	minlength: 5,
		        required: true
		      },
		      pass2: {
		        minlength: 5,
		        required: true
		      }
		    },
		    highlight: function(label) {
		    	$(label).closest('.control-group').addClass('error');
		    },
		    success: function(label) {
		    	label
		    		.text('OK!').addClass('valid')
		    		.closest('.control-group').addClass('success');
		    }
		  });
	  
		$("input#new-user").click(function () { 
			$('#register-form').show("fast");
			$('#login-form').hide();
			$('#div-confirm').show("fast");
		    $('#div-username').show("fast");
		    $('#div-email').show("fast");
		    $('#div-password').show("fast");
		    $('#register').show("fast");
		});

		$("input#existing").click(function () { 
			$('#register-form').hide();
		    $('#login-form').show("fast");
		});

}); // end document.ready

