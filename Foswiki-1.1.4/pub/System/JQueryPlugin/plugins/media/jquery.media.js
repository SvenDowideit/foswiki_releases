(function(c){var h=c.browser.msie&&c.browser.version<9;c.fn.media=function(m,l,n){if(m=="undo"){return this.each(function(){var p=c(this);var o=p.data("media.origHTML");if(o){p.replaceWith(o)}})}return this.each(function(){if(typeof m=="function"){n=l;l=m;m={}}var w=g(this,m);if(typeof l=="function"){l(this,w)}var v=j();var p=v.exec(w.src.toLowerCase())||[""];w.type?p[0]=w.type:p.shift();for(var u=0;u<p.length;u++){fn=p[u].toLowerCase();if(e(fn[0])){fn="fn"+fn}if(!c.fn.media[fn]){continue}var t=c.fn.media[fn+"_player"];if(!w.params){w.params={}}if(t){var s=t.autoplayAttr=="autostart";w.params[t.autoplayAttr||"autoplay"]=s?(w.autoplay?1:0):w.autoplay?true:false}var q=c.fn.media[fn](this,w);q.css("backgroundColor",w.bgColor).width(w.width).height(w.height);if(typeof n=="function"){n(this,q[0],w,t.name)}break}})};c.fn.media.mapFormat=function(m,l){if(!m||!l||!c.fn.media.defaults.players[l]){return}m=m.toLowerCase();if(e(m[0])){m="fn"+m}c.fn.media[m]=c.fn.media[l];c.fn.media[m+"_player"]=c.fn.media.defaults.players[l]};c.fn.media.defaults={standards:true,canUndo:true,width:400,height:400,autoplay:0,bgColor:"#ffffff",params:{wmode:"transparent"},attrs:{},flvKeyName:"file",flashvars:{},flashVersion:"7",expressInstaller:null,flvPlayer:"mediaplayer.swf",mp3Player:"mediaplayer.swf",silverlight:{inplaceInstallPrompt:"true",isWindowless:"true",framerate:"24",version:"0.9",onError:null,onLoad:null,initParams:null,userContext:null}};c.fn.media.defaults.players={flash:{name:"flash",title:"Flash",types:"flv,mp3,swf",mimetype:"application/x-shockwave-flash",pluginspage:"http://www.adobe.com/go/getflashplayer",ieAttrs:{classid:"clsid:d27cdb6e-ae6d-11cf-96b8-444553540000",type:"application/x-oleobject",codebase:"http://fpdownload.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version="+c.fn.media.defaults.flashVersion}},quicktime:{name:"quicktime",title:"QuickTime",mimetype:"video/quicktime",pluginspage:"http://www.apple.com/quicktime/download/",types:"aif,aiff,aac,au,bmp,gsm,mov,mid,midi,mpg,mpeg,mp4,m4a,psd,qt,qtif,qif,qti,snd,tif,tiff,wav,3g2,3gp",ieAttrs:{classid:"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B",codebase:"http://www.apple.com/qtactivex/qtplugin.cab"}},realplayer:{name:"real",title:"RealPlayer",types:"ra,ram,rm,rpm,rv,smi,smil",mimetype:"audio/x-pn-realaudio-plugin",pluginspage:"http://www.real.com/player/",autoplayAttr:"autostart",ieAttrs:{classid:"clsid:CFCDAA03-8BE4-11cf-B84B-0020AFBBCCFA"}},winmedia:{name:"winmedia",title:"Windows Media",types:"asx,asf,avi,wma,wmv",mimetype:c.browser.mozilla&&k()?"application/x-ms-wmp":"application/x-mplayer2",pluginspage:"http://www.microsoft.com/Windows/MediaPlayer/",autoplayAttr:"autostart",oUrl:"url",ieAttrs:{classid:"clsid:6BF52A52-394A-11d3-B153-00C04F79FAA6",type:"application/x-oleobject"}},img:{name:"img",title:"Image",types:"gif,png,jpg"},iframe:{name:"iframe",types:"html,pdf"},silverlight:{name:"silverlight",types:"xaml"}};function k(){var l=navigator.plugins;for(var m=0;m<l.length;m++){var n=l[m];if(n.filename=="np-mswmp.dll"){return true}}return false}var a=1;for(var i in c.fn.media.defaults.players){var d=c.fn.media.defaults.players[i].types;c.each(d.split(","),function(l,m){if(e(m[0])){m="fn"+m}c.fn.media[m]=c.fn.media[i]=b(i);c.fn.media[m+"_player"]=c.fn.media.defaults.players[i]})}function j(){var m="";for(var l in c.fn.media.defaults.players){if(m.length){m+=","}m+=c.fn.media.defaults.players[l].types}return new RegExp("\\.("+m.replace(/,/ig,"|")+")\\b")}function b(l){return function(n,m){return f(n,m,l)}}function e(l){return"0123456789".indexOf(l)>-1}function g(o,D){D=D||{};var C=c(o);var B=o.className||"";var A=c.metadata?C.metadata():c.meta?C.data():{};A=A||{};var z=A.width||parseInt(((B.match(/\bw:(\d+)/)||[])[1]||0))||parseInt(((B.match(/\bwidth:(\d+)/)||[])[1]||0));var t=A.height||parseInt(((B.match(/\bh:(\d+)/)||[])[1]||0))||parseInt(((B.match(/\bheight:(\d+)/)||[])[1]||0));if(z){A.width=z}if(t){A.height=t}if(B){A.cls=B}var q="data-";for(var s=0;s<o.attributes.length;s++){var y=o.attributes[s],r=c.trim(y.name);var u=r.indexOf(q);if(u===0){r=r.substring(q.length);A[r]=y.value}}var y=c.fn.media.defaults;var x=D;var v=A;var m={params:{bgColor:D.bgColor||c.fn.media.defaults.bgColor}};var l=c.extend({},y,x,v);c.each(["attrs","params","flashvars","silverlight"],function(n,p){l[p]=c.extend({},m[p]||{},y[p]||{},x[p]||{},v[p]||{})});if(typeof l.caption=="undefined"){l.caption=C.text()}l.src=l.src||C.attr("href")||C.attr("src")||"unknown";return l}c.fn.media.swf=function(q,l){if(!window.SWFObject&&!window.swfobject){if(l.flashvars){var t=[];for(var r in l.flashvars){t.push(r+"="+l.flashvars[r])}if(!l.params){l.params={}}l.params.flashvars=t.join("&")}return f(q,l,"flash")}var n=q.id?(' id="'+q.id+'"'):"";var u=l.cls?(' class="'+l.cls+'"'):"";var s=c("<div"+n+u+">");if(window.swfobject){c(q).after(s).appendTo(s);if(!q.id){q.id="movie_player_"+a++}swfobject.embedSWF(l.src,q.id,l.width,l.height,l.flashVersion,l.expressInstaller,l.flashvars,l.params,l.attrs)}else{c(q).after(s).remove();var o=new SWFObject(l.src,"movie_player_"+a++,l.width,l.height,l.flashVersion,l.bgColor);if(l.expressInstaller){o.useExpressInstall(l.expressInstaller)}for(var m in l.params){if(m!="bgColor"){o.addParam(m,l.params[m])}}for(var r in l.flashvars){o.addVariable(r,l.flashvars[r])}o.write(s[0])}if(l.caption){c("<div>").appendTo(s).html(l.caption)}return s};c.fn.media.flv=c.fn.media.mp3=function(o,p){var q=p.src;var n=/\.mp3\b/i.test(q)?c.fn.media.defaults.mp3Player:c.fn.media.defaults.flvPlayer;var m=p.flvKeyName;q=encodeURIComponent(q);p.src=n;p.src=p.src+"?"+m+"="+(q);var l={};l[m]=q;p.flashvars=c.extend({},l,p.flashvars);return c.fn.media.swf(o,p)};c.fn.media.xaml=function(r,s){if(!window.Sys||!window.Sys.Silverlight){if(c.fn.media.xaml.warning){return}c.fn.media.xaml.warning=1;alert("You must include the Silverlight.js script.");return}var q={width:s.width,height:s.height,background:s.bgColor,inplaceInstallPrompt:s.silverlight.inplaceInstallPrompt,isWindowless:s.silverlight.isWindowless,framerate:s.silverlight.framerate,version:s.silverlight.version};var o={onError:s.silverlight.onError,onLoad:s.silverlight.onLoad};var p=r.id?(' id="'+r.id+'"'):"";var n=s.id||"AG"+a++;var m=s.cls?(' class="'+s.cls+'"'):"";var l=c("<div"+p+m+">");c(r).after(l).remove();Sys.Silverlight.createObjectEx({source:s.src,initParams:s.silverlight.initParams,userContext:s.silverlight.userContext,id:n,parentElement:l[0],properties:q,events:o});if(s.caption){c("<div>").appendTo(l).html(s.caption)}return l};function f(r,l,w){var A=c(r);var q=c.fn.media.defaults.players[w];if(w=="iframe"){q=c('<iframe width="'+l.width+'" height="'+l.height+'" >');q.attr("src",l.src);q.css("backgroundColor",q.bgColor)}else{if(w=="img"){q=c("<img>");q.attr("src",l.src);l.width&&q.attr("width",l.width);l.height&&q.attr("height",l.height);q.css("backgroundColor",q.bgColor)}else{if(h){var u=['<object width="'+l.width+'" height="'+l.height+'" '];for(var x in l.attrs){u.push(x+'="'+l.attrs[x]+'" ')}for(var x in q.ieAttrs||{}){var y=q.ieAttrs[x];if(x=="codebase"&&window.location.protocol=="https:"){y=y.replace("http","https")}u.push(x+'="'+y+'" ')}u.push("></object>");var n=['<param name="'+(q.oUrl||"src")+'" value="'+l.src+'">'];for(var x in l.params){n.push('<param name="'+x+'" value="'+l.params[x]+'">')}var q=document.createElement(u.join(""));for(var s=0;s<n.length;s++){q.appendChild(document.createElement(n[s]))}}else{if(l.standards){var u=['<object type="'+q.mimetype+'" width="'+l.width+'" height="'+l.height+'"'];if(l.src){u.push(' data="'+l.src+'" ')}if(c.browser.msie){for(var x in q.ieAttrs||{}){var y=q.ieAttrs[x];if(x=="codebase"&&window.location.protocol=="https:"){y=y.replace("http","https")}u.push(x+'="'+y+'" ')}}u.push(">");u.push('<param name="'+(q.oUrl||"src")+'" value="'+l.src+'">');for(var x in l.params){if(x=="wmode"&&w!="flash"){continue}u.push('<param name="'+x+'" value="'+l.params[x]+'">')}u.push("<div><p><strong>"+q.title+" Required</strong></p><p>"+q.title+' is required to view this media. <a href="'+q.pluginspage+'">Download Here</a>.</p></div>');u.push("</object>")}else{var u=['<embed width="'+l.width+'" height="'+l.height+'" style="display:block"'];if(l.src){u.push(' src="'+l.src+'" ')}for(var x in l.attrs){u.push(x+'="'+l.attrs[x]+'" ')}for(var x in q.eAttrs||{}){u.push(x+'="'+q.eAttrs[x]+'" ')}for(var x in l.params){if(x=="wmode"&&w!="flash"){continue}u.push(x+'="'+l.params[x]+'" ')}u.push("></embed>")}}}}var m=r.id?(' id="'+r.id+'"'):"";var z=l.cls?(' class="'+l.cls+'"'):"";var t=c("<div"+m+z+">");A.after(t).remove();(h||w=="iframe"||w=="img")?t.append(q):t.html(u.join(""));if(l.caption){c("<div>").appendTo(t).html(l.caption)}return t}})(jQuery);