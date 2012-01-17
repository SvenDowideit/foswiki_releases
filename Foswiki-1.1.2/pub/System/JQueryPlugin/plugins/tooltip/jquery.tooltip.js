(function(e){var b={},k,m,o,j=e.browser.msie&&/MSIE\s(5\.5|6\.)/.test(navigator.userAgent),a=false;e.tooltip={blocked:false,defaults:{delay:200,fade:false,showURL:true,extraClass:"",top:15,left:15,id:"tooltip"},block:function(){e.tooltip.blocked=!e.tooltip.blocked}};e.fn.extend({tooltip:function(p){p=e.extend({},e.tooltip.defaults,p);h(p);return this.each(function(){e.data(this,"tooltip",p);this.tOpacity=b.parent.css("opacity");this.tooltipText=this.title;e(this).removeAttr("title");this.alt=""}).mouseover(l).mouseout(f).click(f)},fixPNG:j?function(){return this.each(function(){var p=e(this).css("backgroundImage");if(p.match(/^url\(["']?(.*\.png)["']?\)$/i)){p=RegExp.$1;e(this).css({backgroundImage:"none",filter:"progid:DXImageTransform.Microsoft.AlphaImageLoader(enabled=true, sizingMethod=crop, src='"+p+"')"}).each(function(){var q=e(this).css("position");if(q!="absolute"&&q!="relative"){e(this).css("position","relative")}})}})}:function(){return this},unfixPNG:j?function(){return this.each(function(){e(this).css({filter:"",backgroundImage:""})})}:function(){return this},hideWhenEmpty:function(){return this.each(function(){e(this)[e(this).html()?"show":"hide"]()})},url:function(){return this.attr("href")||this.attr("src")}});function h(p){if(b.parent){return}b.parent=e('<div id="'+p.id+'"><h3></h3><div class="body"></div><div class="url"></div></div>').appendTo(document.body).hide();if(e.fn.bgiframe){b.parent.bgiframe()}b.title=e("h3",b.parent);b.body=e("div.body",b.parent);b.url=e("div.url",b.parent)}function c(p){return e.data(p,"tooltip")}function g(p){if(c(this).delay){o=setTimeout(n,c(this).delay)}else{n()}a=!!c(this).track;e(document.body).bind("mousemove",d);d(p)}function l(){if(e.tooltip.blocked||this==k||(!this.tooltipText&&!c(this).bodyHandler)){return}k=this;m=this.tooltipText;if(c(this).bodyHandler){b.title.hide();var s=c(this).bodyHandler.call(this);if(s.nodeType||s.jquery){b.body.empty().append(s)}else{b.body.html(s)}b.body.show()}else{if(c(this).showBody){var r=m.split(c(this).showBody);b.title.empty();b.body.empty();if(r.length>1){b.title.html(r.shift()).show();for(var q=0,p;(p=r[q]);q++){if(q>0){b.body.append("<br/>")}b.body.append(p)}}else{b.body.html(r.shift()).show()}b.body.hideWhenEmpty();b.title.hideWhenEmpty()}else{b.title.html(m).show();b.body.hide()}}if(c(this).showURL&&e(this).url()){b.url.html(e(this).url().replace("http://","")).show()}else{b.url.hide()}b.parent.addClass(c(this).extraClass);if(c(this).fixPNG){b.parent.fixPNG()}g.apply(this,arguments)}function n(){o=null;if((!j||!e.fn.bgiframe)&&c(k).fade){if(b.parent.is(":animated")){b.parent.stop().show().fadeTo(c(k).fade,k.tOpacity)}else{b.parent.is(":visible")?b.parent.fadeTo(c(k).fade,k.tOpacity):b.parent.fadeIn(c(k).fade)}}else{b.parent.show()}d()}function d(s){if(e.tooltip.blocked){return}if(s&&s.target.tagName=="OPTION"){return}if(!a&&b.parent.is(":visible")){e(document.body).unbind("mousemove",d)}if(k==undefined){e(document.body).unbind("mousemove",d);return}b.parent.removeClass("viewport-right").removeClass("viewport-bottom");var u=b.parent[0].offsetLeft;var t=b.parent[0].offsetTop;if(s){u=s.pageX+c(k).left;t=s.pageY+c(k).top;var q="auto";if(c(k).positionLeft){q=e(window).width()-u;u="auto"}b.parent.css({left:u,right:q,top:t})}var p=i(),r=b.parent[0];if(p.x+p.cx<r.offsetLeft+r.offsetWidth){u-=r.offsetWidth+20+c(k).left;b.parent.css({left:u+"px"}).addClass("viewport-right")}if(p.y+p.cy<r.offsetTop+r.offsetHeight){t-=r.offsetHeight+20+c(k).top;b.parent.css({top:t+"px"}).addClass("viewport-bottom")}}function i(){return{x:e(window).scrollLeft(),y:e(window).scrollTop(),cx:e(window).width(),cy:e(window).height()}}function f(r){if(e.tooltip.blocked){return}if(o){clearTimeout(o)}k=null;var q=c(this);function p(){b.parent.removeClass(q.extraClass).hide().css("opacity","")}if((!j||!e.fn.bgiframe)&&q.fade){if(b.parent.is(":animated")){b.parent.stop().fadeTo(q.fade,0,p)}else{b.parent.stop().fadeOut(q.fade,p)}}else{p()}if(c(this).fixPNG){b.parent.unfixPNG()}}})(jQuery);