foswiki.Window={POPUP_WINDOW_WIDTH:600,POPUP_WINDOW_HEIGHT:480,POPUP_ATTRIBUTES:"titlebar=0,resizable,scrollbars",openPopup:function(f,k,e){if(!f){return null}var a="";var c="";var g=f;var m=[];var d=foswiki.Window.POPUP_WINDOW_WIDTH;var o=foswiki.Window.POPUP_WINDOW_HEIGHT;var j=foswiki.Window.POPUP_ATTRIBUTES;if(k){var i=[];if(k.web!=undefined){i.push(k.web)}if(k.topic!=undefined){i.push(k.topic)}g+=i.join("/");var h=[];if(k.skin!=undefined){h.push("skin="+k.skin)}if(k.template!=undefined){h.push("template="+k.template)}if(k.section!=undefined){h.push("section="+k.section)}if(k.cover!=undefined){h.push("cover="+k.cover)}if(k.urlparams!=undefined){h.push(k.urlparams)}a=h.join(";");if(a.length>0){a="?"+a}if(k.topic!=undefined){c=k.topic}if(k.name!=undefined){c=k.name}if(k.width!=undefined){d=k.width}if(k.height!=undefined){o=k.height}if(k.attributes!=undefined){j=k.attributes}}m.push("width="+d);m.push("height="+o);m.push(j);var n=m.join(",");var b=g+a;var l=open(b,c,n);if(l){l.focus();return l}if(e&&e.document){e.document.location.href=g}return null}};function launchWindow(a,b){foswiki.Window.openPopup(foswiki.getPreference("SCRIPTURLPATH")+"/view"+foswiki.getPreference("SCRIPTSUFFIX")+"/",{web:a,topic:b,template:"viewplain"});return false};