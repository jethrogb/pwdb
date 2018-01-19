function makeEditable(parent) {
	parent.find('.editable').editable({
		type: 'text',
		url: '?a=u',
	});
	parent.find('.deletehandle').off('click').on('click',ajaxDelete);
	parent.find('.copyhandle').off('click').on('click',copyPassword);
	parent.find('.showhandle').off('click').on('click',toggleVisibility);
}
function ajaxDelete(e) {
	var row=$(e.target).parents('tr');
	var pk=row.attr('id');
	// TODO: Just copy the entire thead tr+this tr, then transpose for use in dialog.
	var dialog=$('<div>Delete password for user <b style="white-space:nowrap" data-user></b> at <b style="white-space:nowrap" data-host></b>?</div>');
	dialog.find('[data-user]').text(row.find('[data-name="user"]').text());
	dialog.find('[data-host]').text(row.find('[data-name="host"]').text());
	dialog.dialog({
		resizable: false,
		height: 'auto',
		modal: true,
		title: "Confirm deletion",
		buttons: {
			Delete: function() {
				var ajax=$.post('?a=d','pk='+pk);
	
				ajax.fail(function() {
					alert('Error during deletion.');
				});
				ajax.done(function() {
					row.remove();
				});
				dialog.dialog("close");
			},
			Cancel: function() {
				dialog.dialog("close");
			}
		}
	});
}
function ajaxSort(e,ui) {
	var myid=ui.item.attr('id');
	var afterid=ui.item.prev('tr').not('ui-sortable-placeholder').attr('id');
	if (afterid==undefined) afterid='top';
	var ajax=$.post('?a=m','pk='+myid+'&after='+afterid);

	$("#mtable").sortable("disable");
	var pholder=$("#sortplaceholder").clone().show();
	ui.item.after(pholder);
	ajax.always(function() {
		$("#mtable").sortable("enable");
		pholder.remove();
	});
	ajax.fail(function () {ui.item.effect("highlight",{color:"#f88"})});
	var ret=false;
	ajax.done(function() {
		ret=true;
		if (afterid=='top')
		{
			$("#mtable").prepend(ui.item);
		}
		else
		{
			$("#mtable #"+afterid).after(ui.item);
		}
		ui.item.effect("highlight",{color:"#8f8"});
		$("#mtable").refresh();
	});
	return ret;
}
function ajaxAdd(e) {
	$('#addprogress').show();
	$('#adderror').hide();
	$('#addsubmit').hide();
	var f=$(e.target);
	var ajax=$.post(f.attr('action'),f.serialize());
	ajax.always(function() {$('#addprogress').hide();$('#addsubmit').show()});
	ajax.fail(function(data) {$('#adderror').show().children('td').html(data)});
	ajax.done(function(data) {makeEditable($('#mtable').append($(data).effect("highlight",{color:"#8f8"})));window.scroll(0,document.body.scrollHeight);e.target.reset()});
	e.preventDefault();
}
function copyPassword(e) {
	var apass=$(e.target).siblings('a.pass');
	var selection = getSelection();
	selection.removeAllRanges();
	var range = document.createRange();
	range.selectNodeContents(apass[0]);
	selection.addRange(range);
	document.execCommand("copy");
	selection.removeAllRanges();
	$(e.target).parents('td').effect("highlight",{color:"#8f8"});
}
function toggleVisibility(e) {
	var apass=$(e.target).siblings('a.pass');
	apass.toggleClass('hidden');
}
$.fn.editable.defaults.mode = 'inline';
$(document).ready(function() {
	makeEditable($(document));
	$('#mtable').sortable({
		update: ajaxSort,
		helper: 'clone',
		start: function(e,ui){ui.item.show()},
		handle: '.sorthandle',
	});
	$('#addform').submit(ajaxAdd);
});
