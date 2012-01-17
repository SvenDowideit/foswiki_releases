var Pattern = {

	metaTags:[],
	
	createTwikiActionFormStepSign:function(el) {
		var sign = '&#9658;';
		var newEl = foswiki.HTML.insertBeforeElement(
			el,
			'span',
			sign
		);
		newEl.className = 'foswikiActionFormStepSign';
	},

	/**
	Creates a attachment counter in the attachment table twisty.
	*/
	setAttachmentCount:function(inTableElement) {		
		var count = inTableElement.getElementsByTagName("tr").length - 1;
		var countStr = " " + "<span class='patternSmallLinkToHeader'>" + ' '  + count + "<\/span>";
		var showElem = document.getElementById('topicattachmentslistshow');
		if (showElem != undefined) {
			var elems = foswiki.getElementsByClassName(showElem, 'patternAtachmentHeader');
			if (elems && elems[0]) {
				elems[0].innerHTML += countStr;
			}
		}
		var hideElem = document.getElementById('topicattachmentslisthide');
		if (hideElem != undefined) {
			var elems = foswiki.getElementsByClassName(hideElem, 'patternAtachmentHeader');
			if (elems && elems[0]) {
				elems[0].innerHTML += countStr;
			}
		}
	},
	
	addSearchResultsCounter:function(el) {
		var count = foswiki.HTML.getHtmlOfElement(el);
		Pattern.searchResultsCount += parseInt(count);
	},
	
	displayTotalSearchResultsCount:function(el) {
		// write result count
		if (Pattern.searchResultsCount >= 10) {
			var text = " " + TEXT_NUM_TOPICS + " <b>" + Pattern.searchResultsCount + " <\/b>";
			foswiki.HTML.setHtmlOfElement(el, text);			
			// reset for next count
			Pattern.searchResultsCount = 0;
		}
	},
	
	displayModifySearchLink:function() {
		var linkContainer = document.getElementById('foswikiModifySearchContainer');
		if (linkContainer != null) {
			if (Pattern.searchResultsCount > 0) {
				var linkText=' <a href="#" onclick="location.hash=\'foswikiSearchForm\'; return false;"><span class="foswikiLinkLabel foswikiSmallish">' + TEXT_MODIFY_SEARCH + '</span></a>';
					foswiki.HTML.setHtmlOfElement(linkContainer, linkText);
			}
		}
	}
}

var patternRules = {
	'.foswikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	},
	'#jumpFormField' : function(el) {
		foswiki.Form.initBeforeFocusText(el,TEXT_JUMP);
		el.onfocus = function() {
			foswiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			foswiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#quickSearchBox' : function(el) {
		foswiki.Form.initBeforeFocusText(el,TEXT_SEARCH);
		el.onfocus = function() {
			foswiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			foswiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#foswikiAttachmentsTable' : function(el) {
		Pattern.setAttachmentCount(el);
	},
	'body.patternEditPage' : function(el) {
		foswiki.Event.addLoadEvent(initForm, false); // call after Behaviour
	},
	'.foswikiSearchResultCount' : function(el) {
		Pattern.addSearchResultsCounter(el);
	},
	'#foswikiNumberOfResultsContainer' : function(el) {
		Pattern.displayTotalSearchResultsCount(el);
	},
	'#foswikiWebSearchForm':function(el) {
		Pattern.displayModifySearchLink();
	},
	'.foswikiPopUp':function(el) {
		el.onclick = function() {
			foswiki.Window.openPopup(el.href, {template:"viewplain"});
			return false;
		}
	},
	'.foswikiFocus':function(el) {
		el.focus();
	},
	'.foswikiChangeFormButton':function(el) {
		el.onclick = function() {
			suppressSaveValidation();
		}
	}
};
Behaviour.register(patternRules);

var initForm; // in case initForm is not defined (f.e. when TinyMCE is used and foswiki_edit.js is not loaded
var TEXT_JUMP = foswiki.getMetaTag('TEXT_JUMP');
var TEXT_SEARCH = foswiki.getMetaTag('TEXT_SEARCH');
var TEXT_NUM_TOPICS = foswiki.getMetaTag('TEXT_NUM_TOPICS');
var TEXT_MODIFY_SEARCH = foswiki.getMetaTag('TEXT_MODIFY_SEARCH');
var SCRIPTURLPATH = foswiki.getMetaTag('SCRIPTURLPATH');
var SCRIPTSUFFIX = foswiki.getMetaTag('SCRIPTSUFFIX');
var WEB = foswiki.getMetaTag('WEB');
var TOPIC = foswiki.getMetaTag('TOPIC');
