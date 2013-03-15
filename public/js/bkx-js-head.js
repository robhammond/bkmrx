// Functions that must go in HTML <head> element

/* Date separation function */
function dateSeparate (dates) {
	for (i=0;i<dates.length;i++) {
		$('div.bkmrk').siblings('[added="' + dates[i] + '"]')
		.first().before('<div class="d">' + dates[i] + '</div>');
	}
}
/* End date separation */