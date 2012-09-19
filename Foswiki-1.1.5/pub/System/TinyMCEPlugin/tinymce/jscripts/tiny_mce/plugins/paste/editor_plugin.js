(function(){var each=tinymce.each,defs={paste_auto_cleanup_on_paste:true,paste_enable_default_filters:true,paste_block_drop:false,paste_retain_style_properties:"none",paste_strip_class_attributes:"mso",paste_remove_spans:false,paste_remove_styles:false,paste_remove_styles_if_webkit:true,paste_convert_middot_lists:true,paste_convert_headers_to_strong:false,paste_dialog_width:"450",paste_dialog_height:"400",paste_text_use_dialog:false,paste_text_sticky:false,paste_text_sticky_default:false,paste_text_notifyalways:false,paste_text_linebreaktype:"combined",paste_text_replacements:[[/\u2026/g,"..."],[/[\x93\x94\u201c\u201d]/g,'"'],[/[\x60\x91\x92\u2018\u2019]/g,"'"]]};function getParam(ed,name){return ed.getParam(name,defs[name]);}
tinymce.create('tinymce.plugins.PastePlugin',{init:function(ed,url){var t=this;t.editor=ed;t.url=url;t.onPreProcess=new tinymce.util.Dispatcher(t);t.onPostProcess=new tinymce.util.Dispatcher(t);t.onPreProcess.add(t._preProcess);t.onPostProcess.add(t._postProcess);t.onPreProcess.add(function(pl,o){ed.execCallback('paste_preprocess',pl,o);});t.onPostProcess.add(function(pl,o){ed.execCallback('paste_postprocess',pl,o);});ed.onKeyDown.addToTop(function(ed,e){if(((tinymce.isMac?e.metaKey:e.ctrlKey)&&e.keyCode==86)||(e.shiftKey&&e.keyCode==45))
return false;});ed.pasteAsPlainText=getParam(ed,'paste_text_sticky_default');function process(o,force_rich){var dom=ed.dom,rng;t.onPreProcess.dispatch(t,o);o.node=dom.create('div',0,o.content);if(tinymce.isGecko){rng=ed.selection.getRng(true);if(rng.startContainer==rng.endContainer&&rng.startContainer.nodeType==3){if(o.node.childNodes.length===1&&/^(p|h[1-6]|pre)$/i.test(o.node.firstChild.nodeName)&&o.content.indexOf('__MCE_ITEM__')===-1)
dom.remove(o.node.firstChild,true);}}
t.onPostProcess.dispatch(t,o);o.content=ed.serializer.serialize(o.node,{getInner:1,forced_root_block:''});if((!force_rich)&&(ed.pasteAsPlainText)){t._insertPlainText(o.content);if(!getParam(ed,"paste_text_sticky")){ed.pasteAsPlainText=false;ed.controlManager.setActive("pastetext",false);}}else{t._insert(o.content);}}
ed.addCommand('mceInsertClipboardContent',function(u,o){process(o,true);});if(!getParam(ed,"paste_text_use_dialog")){ed.addCommand('mcePasteText',function(u,v){var cookie=tinymce.util.Cookie;ed.pasteAsPlainText=!ed.pasteAsPlainText;ed.controlManager.setActive('pastetext',ed.pasteAsPlainText);if((ed.pasteAsPlainText)&&(!cookie.get("tinymcePasteText"))){if(getParam(ed,"paste_text_sticky")){ed.windowManager.alert(ed.translate('paste.plaintext_mode_sticky'));}else{ed.windowManager.alert(ed.translate('paste.plaintext_mode'));}
if(!getParam(ed,"paste_text_notifyalways")){cookie.set("tinymcePasteText","1",new Date(new Date().getFullYear()+1,12,31))}}});}
ed.addButton('pastetext',{title:'paste.paste_text_desc',cmd:'mcePasteText'});ed.addButton('selectall',{title:'paste.selectall_desc',cmd:'selectall'});function grabContent(e){var n,or,rng,oldRng,sel=ed.selection,dom=ed.dom,body=ed.getBody(),posY,textContent;if(e.clipboardData||dom.doc.dataTransfer){textContent=(e.clipboardData||dom.doc.dataTransfer).getData('Text');if(ed.pasteAsPlainText){e.preventDefault();process({content:dom.encode(textContent).replace(/\r?\n/g,'<br />')});return;}}
if(dom.get('_mcePaste'))
return;n=dom.add(body,'div',{id:'_mcePaste','class':'mcePaste','data-mce-bogus':'1'},'\uFEFF\uFEFF');if(body!=ed.getDoc().body)
posY=dom.getPos(ed.selection.getStart(),body).y;else
posY=body.scrollTop+dom.getViewPort(ed.getWin()).y;dom.setStyles(n,{position:'absolute',left:tinymce.isGecko?-40:0,top:posY-25,width:1,height:1,overflow:'hidden'});if(tinymce.isIE){oldRng=sel.getRng();rng=dom.doc.body.createTextRange();rng.moveToElementText(n);rng.execCommand('Paste');dom.remove(n);if(n.innerHTML==='\uFEFF\uFEFF'){ed.execCommand('mcePasteWord');e.preventDefault();return;}
sel.setRng(oldRng);sel.setContent('');setTimeout(function(){process({content:n.innerHTML});},0);return tinymce.dom.Event.cancel(e);}else{function block(e){e.preventDefault();};dom.bind(ed.getDoc(),'mousedown',block);dom.bind(ed.getDoc(),'keydown',block);or=ed.selection.getRng();n=n.firstChild;rng=ed.getDoc().createRange();rng.setStart(n,0);rng.setEnd(n,2);sel.setRng(rng);window.setTimeout(function(){var h='',nl;if(!dom.select('div.mcePaste > div.mcePaste').length){nl=dom.select('div.mcePaste');each(nl,function(n){var child=n.firstChild;if(child&&child.nodeName=='DIV'&&child.style.marginTop&&child.style.backgroundColor){dom.remove(child,1);}
each(dom.select('span.Apple-style-span',n),function(n){dom.remove(n,1);});each(dom.select('br[data-mce-bogus]',n),function(n){dom.remove(n);});if(n.parentNode.className!='mcePaste')
h+=n.innerHTML;});}else{h='<p>'+dom.encode(textContent).replace(/\r?\n\r?\n/g,'</p><p>').replace(/\r?\n/g,'<br />')+'</p>';}
each(dom.select('div.mcePaste'),function(n){dom.remove(n);});if(or)
sel.setRng(or);process({content:h});dom.unbind(ed.getDoc(),'mousedown',block);dom.unbind(ed.getDoc(),'keydown',block);},0);}}
if(getParam(ed,"paste_auto_cleanup_on_paste")){if(tinymce.isOpera||/Firefox\/2/.test(navigator.userAgent)){ed.onKeyDown.addToTop(function(ed,e){if(((tinymce.isMac?e.metaKey:e.ctrlKey)&&e.keyCode==86)||(e.shiftKey&&e.keyCode==45))
grabContent(e);});}else{ed.onPaste.addToTop(function(ed,e){return grabContent(e);});}}
ed.onInit.add(function(){ed.controlManager.setActive("pastetext",ed.pasteAsPlainText);if(getParam(ed,"paste_block_drop")){ed.dom.bind(ed.getBody(),['dragend','dragover','draggesture','dragdrop','drop','drag'],function(e){e.preventDefault();e.stopPropagation();return false;});}});t._legacySupport();},getInfo:function(){return{longname:'Paste text/word',author:'Moxiecode Systems AB',authorurl:'http://tinymce.moxiecode.com',infourl:'http://wiki.moxiecode.com/index.php/TinyMCE:Plugins/paste',version:tinymce.majorVersion+"."+tinymce.minorVersion};},_preProcess:function(pl,o){var ed=this.editor,h=o.content,grep=tinymce.grep,explode=tinymce.explode,trim=tinymce.trim,len,stripClass;function process(items){each(items,function(v){if(v.constructor==RegExp)
h=h.replace(v,'');else
h=h.replace(v[0],v[1]);});}
if(ed.settings.paste_enable_default_filters==false){return;}
if(tinymce.isIE&&document.documentMode>=9){process([[/(?:<br>&nbsp;[\s\r\n]+|<br>)*(<\/?(h[1-6r]|p|div|address|pre|form|table|tbody|thead|tfoot|th|tr|td|li|ol|ul|caption|blockquote|center|dl|dt|dd|dir|fieldset)[^>]*>)(?:<br>&nbsp;[\s\r\n]+|<br>)*/g,'$1']]);process([[/<br><br>/g,'<BR><BR>'],[/<br>/g,' '],[/<BR><BR>/g,'<br>']]);}
if(/class="?Mso|style="[^"]*\bmso-|w:WordDocument/i.test(h)||o.wordContent){o.wordContent=true;process([/^\s*(&nbsp;)+/gi,/(&nbsp;|<br[^>]*>)+\s*$/gi]);if(getParam(ed,"paste_convert_headers_to_strong")){h=h.replace(/<p [^>]*class="?MsoHeading"?[^>]*>(.*?)<\/p>/gi,"<p><strong>$1</strong></p>");}
if(getParam(ed,"paste_convert_middot_lists")){process([[/<!--\[if !supportLists\]-->/gi,'$&__MCE_ITEM__'],[/(<span[^>]+(?:mso-list:|:\s*symbol)[^>]+>)/gi,'$1__MCE_ITEM__'],[/(<p[^>]+(?:MsoListParagraph)[^>]+>)/gi,'$1__MCE_ITEM__']]);}
process([/<!--[\s\S]+?-->/gi,/<(!|script[^>]*>.*?<\/script(?=[>\s])|\/?(\?xml(:\w+)?|img|meta|link|style|\w:\w+)(?=[\s\/>]))[^>]*>/gi,[/<(\/?)s>/gi,"<$1strike>"],[/&nbsp;/gi,"\u00a0"]]);do{len=h.length;h=h.replace(/(<[a-z][^>]*\s)(?:id|name|language|type|on\w+|\w+:\w+)=(?:"[^"]*"|\w+)\s?/gi,"$1");}while(len!=h.length);if(getParam(ed,"paste_retain_style_properties").replace(/^none$/i,"").length==0){h=h.replace(/<\/?span[^>]*>/gi,"");}else{process([[/<span\s+style\s*=\s*"\s*mso-spacerun\s*:\s*yes\s*;?\s*"\s*>([\s\u00a0]*)<\/span>/gi,function(str,spaces){return(spaces.length>0)?spaces.replace(/./," ").slice(Math.floor(spaces.length/2)).split("").join("\u00a0"):"";}],[/(<[a-z][^>]*)\sstyle="([^"]*)"/gi,function(str,tag,style){var n=[],i=0,s=explode(trim(style).replace(/&quot;/gi,"'"),";");each(s,function(v){var name,value,parts=explode(v,":");function ensureUnits(v){return v+((v!=="0")&&(/\d$/.test(v)))?"px":"";}
if(parts.length==2){name=parts[0].toLowerCase();value=parts[1].toLowerCase();switch(name){case"mso-padding-alt":case"mso-padding-top-alt":case"mso-padding-right-alt":case"mso-padding-bottom-alt":case"mso-padding-left-alt":case"mso-margin-alt":case"mso-margin-top-alt":case"mso-margin-right-alt":case"mso-margin-bottom-alt":case"mso-margin-left-alt":case"mso-table-layout-alt":case"mso-height":case"mso-width":case"mso-vertical-align-alt":n[i++]=name.replace(/^mso-|-alt$/g,"")+":"+ensureUnits(value);return;case"horiz-align":n[i++]="text-align:"+value;return;case"vert-align":n[i++]="vertical-align:"+value;return;case"font-color":case"mso-foreground":n[i++]="color:"+value;return;case"mso-background":case"mso-highlight":n[i++]="background:"+value;return;case"mso-default-height":n[i++]="min-height:"+ensureUnits(value);return;case"mso-default-width":n[i++]="min-width:"+ensureUnits(value);return;case"mso-padding-between-alt":n[i++]="border-collapse:separate;border-spacing:"+ensureUnits(value);return;case"text-line-through":if((value=="single")||(value=="double")){n[i++]="text-decoration:line-through";}
return;case"mso-zero-height":if(value=="yes"){n[i++]="display:none";}
return;}
if(/^(mso|column|font-emph|lang|layout|line-break|list-image|nav|panose|punct|row|ruby|sep|size|src|tab-|table-border|text-(?!align|decor|indent|trans)|top-bar|version|vnd|word-break)/.test(name)){return;}
n[i++]=name+":"+parts[1];}});if(i>0){return tag+' style="'+n.join(';')+'"';}else{return tag;}}]]);}}
if(getParam(ed,"paste_convert_headers_to_strong")){process([[/<h[1-6][^>]*>/gi,"<p><strong>"],[/<\/h[1-6][^>]*>/gi,"</strong></p>"]]);}
process([[/Version:[\d.]+\nStartHTML:\d+\nEndHTML:\d+\nStartFragment:\d+\nEndFragment:\d+/gi,'']]);stripClass=getParam(ed,"paste_strip_class_attributes");if(stripClass!=="none"){function removeClasses(match,g1){if(stripClass==="all")
return'';var cls=grep(explode(g1.replace(/^(["'])(.*)\1$/,"$2")," "),function(v){return(/^(?!mso)/i.test(v));});return cls.length?' class="'+cls.join(" ")+'"':'';};h=h.replace(/ class="([^"]+)"/gi,removeClasses);h=h.replace(/ class=([\-\w]+)/gi,removeClasses);}
if(getParam(ed,"paste_remove_spans")){h=h.replace(/<\/?span[^>]*>/gi,"");}
o.content=h;},_postProcess:function(pl,o){var t=this,ed=t.editor,dom=ed.dom,styleProps;if(ed.settings.paste_enable_default_filters==false){return;}
if(o.wordContent){each(dom.select('a',o.node),function(a){if(!a.href||a.href.indexOf('#_Toc')!=-1)
dom.remove(a,1);});if(getParam(ed,"paste_convert_middot_lists")){t._convertLists(pl,o);}
styleProps=getParam(ed,"paste_retain_style_properties");if((tinymce.is(styleProps,"string"))&&(styleProps!=="all")&&(styleProps!=="*")){styleProps=tinymce.explode(styleProps.replace(/^none$/i,""));each(dom.select('*',o.node),function(el){var newStyle={},npc=0,i,sp,sv;if(styleProps){for(i=0;i<styleProps.length;i++){sp=styleProps[i];sv=dom.getStyle(el,sp);if(sv){newStyle[sp]=sv;npc++;}}}
dom.setAttrib(el,'style','');if(styleProps&&npc>0)
dom.setStyles(el,newStyle);else
if(el.nodeName=='SPAN'&&!el.className)
dom.remove(el,true);});}}
if(getParam(ed,"paste_remove_styles")||(getParam(ed,"paste_remove_styles_if_webkit")&&tinymce.isWebKit)){each(dom.select('*[style]',o.node),function(el){el.removeAttribute('style');el.removeAttribute('data-mce-style');});}else{if(tinymce.isWebKit){each(dom.select('*',o.node),function(el){el.removeAttribute('data-mce-style');});}}},_convertLists:function(pl,o){var dom=pl.editor.dom,listElm,li,lastMargin=-1,margin,levels=[],lastType,html;each(dom.select('p',o.node),function(p){var sib,val='',type,html,idx,parents;for(sib=p.firstChild;sib&&sib.nodeType==3;sib=sib.nextSibling)
val+=sib.nodeValue;val=p.innerHTML.replace(/<\/?\w+[^>]*>/gi,'').replace(/&nbsp;/g,'\u00a0');if(/^(__MCE_ITEM__)+[\u2022\u00b7\u00a7\u00d8o\u25CF]\s*\u00a0*/.test(val))
type='ul';if(/^__MCE_ITEM__\s*\w+\.\s*\u00a0+/.test(val))
type='ol';if(type){margin=parseFloat(p.style.marginLeft||0);if(margin>lastMargin)
levels.push(margin);if(!listElm||type!=lastType){listElm=dom.create(type);dom.insertAfter(listElm,p);}else{if(margin>lastMargin){listElm=li.appendChild(dom.create(type));}else if(margin<lastMargin){idx=tinymce.inArray(levels,margin);parents=dom.getParents(listElm.parentNode,type);listElm=parents[parents.length-1-idx]||listElm;}}
each(dom.select('span',p),function(span){var html=span.innerHTML.replace(/<\/?\w+[^>]*>/gi,'');if(type=='ul'&&/^__MCE_ITEM__[\u2022\u00b7\u00a7\u00d8o\u25CF]/.test(html))
dom.remove(span);else if(/^__MCE_ITEM__[\s\S]*\w+\.(&nbsp;|\u00a0)*\s*/.test(html))
dom.remove(span);});html=p.innerHTML;if(type=='ul')
html=p.innerHTML.replace(/__MCE_ITEM__/g,'').replace(/^[\u2022\u00b7\u00a7\u00d8o\u25CF]\s*(&nbsp;|\u00a0)+\s*/,'');else
html=p.innerHTML.replace(/__MCE_ITEM__/g,'').replace(/^\s*\w+\.(&nbsp;|\u00a0)+\s*/,'');li=listElm.appendChild(dom.create('li',0,html));dom.remove(p);lastMargin=margin;lastType=type;}else
listElm=lastMargin=0;});html=o.node.innerHTML;if(html.indexOf('__MCE_ITEM__')!=-1)
o.node.innerHTML=html.replace(/__MCE_ITEM__/g,'');},_insert:function(h,skip_undo){var ed=this.editor,r=ed.selection.getRng();if(!ed.selection.isCollapsed()&&r.startContainer!=r.endContainer)
ed.getDoc().execCommand('Delete',false,null);ed.execCommand('mceInsertContent',false,h,{skip_undo:skip_undo});},_insertPlainText:function(content){var ed=this.editor,linebr=getParam(ed,"paste_text_linebreaktype"),rl=getParam(ed,"paste_text_replacements"),is=tinymce.is;function process(items){each(items,function(v){if(v.constructor==RegExp)
content=content.replace(v,"");else
content=content.replace(v[0],v[1]);});};if((typeof(content)==="string")&&(content.length>0)){if(/<(?:p|br|h[1-6]|ul|ol|dl|table|t[rdh]|div|blockquote|fieldset|pre|address|center)[^>]*>/i.test(content)){process([/[\n\r]+/g]);}else{process([/\r+/g]);}
process([[/<\/(?:p|h[1-6]|ul|ol|dl|table|div|blockquote|fieldset|pre|address|center)>/gi,"\n\n"],[/<br[^>]*>|<\/tr>/gi,"\n"],[/<\/t[dh]>\s*<t[dh][^>]*>/gi,"\t"],/<[a-z!\/?][^>]*>/gi,[/&nbsp;/gi," "],[/(?:(?!\n)\s)*(\n+)(?:(?!\n)\s)*/gi,"$1"],[/\n{3,}/g,"\n\n"]]);content=ed.dom.decode(tinymce.html.Entities.encodeRaw(content));if(is(rl,"array")){process(rl);}else if(is(rl,"string")){process(new RegExp(rl,"gi"));}
if(linebr=="none"){process([[/\n+/g," "]]);}else if(linebr=="br"){process([[/\n/g,"<br />"]]);}else if(linebr=="p"){process([[/\n+/g,"</p><p>"],[/^(.*<\/p>)(<p>)$/,'<p>$1']]);}else{process([[/\n\n/g,"</p><p>"],[/^(.*<\/p>)(<p>)$/,'<p>$1'],[/\n/g,"<br />"]]);}
ed.execCommand('mceInsertContent',false,content);}},_legacySupport:function(){var t=this,ed=t.editor;ed.addCommand("mcePasteWord",function(){ed.windowManager.open({file:t.url+"/pasteword.htm",width:parseInt(getParam(ed,"paste_dialog_width")),height:parseInt(getParam(ed,"paste_dialog_height")),inline:1});});if(getParam(ed,"paste_text_use_dialog")){ed.addCommand("mcePasteText",function(){ed.windowManager.open({file:t.url+"/pastetext.htm",width:parseInt(getParam(ed,"paste_dialog_width")),height:parseInt(getParam(ed,"paste_dialog_height")),inline:1});});}
ed.addButton("pasteword",{title:"paste.paste_word_desc",cmd:"mcePasteWord"});}});tinymce.PluginManager.add("paste",tinymce.plugins.PastePlugin);})();