(function(a){a.fn.gradient=function(c){c=a.extend({from:"000000",to:"ffffff",direction:"horizontal",position:"top",length:null},c||{});var b=function(j,i,k){var h=[],g=1,k=(k<100)?k:100;do{h[h.length]=f(e(j),g,e(i));g-=((100/k)*0.01)}while(g>0);return h},f=function(k,j,l){var g=[];for(var h=0;h<k.length;h++){g[h]=Math.round(k[h]*j)+Math.round(l[h]*(1-j))}return g},e=function(g){return new Array(d(g.substring(0,2)),d(g.substring(2,4)),d(g.substring(4,6)))},d=function(g){return parseInt(g,16)};return this.each(function(){var o=a(this),g=o.innerWidth(),t=o.innerHeight(),q=0,p=0,r=1,m=1,n=[],j=c.length||(c.direction=="vertical"?g:t),l=(c.position=="bottom"?"bottom:0;":"top:0;")+(c.position=="right"?"right:0;":"left:0;"),s=b(c.from,c.to,j);if(c.direction=="horizontal"){m=Math.round(j/s.length)||1;r=g}else{r=Math.round(j/s.length)||1;m=t}n.push('<div class="gradient" style="position: absolute; '+l+" width: "+(c.direction=="vertical"?j+"px":"100%")+"; height: "+(c.direction=="vertical"?"100%":j+"px")+"; overflow: hidden; z-index: 0; background-color: #"+(c.position.indexOf("bottom")!=-1?c.from:c.to)+'">');for(var k=0;k<s.length;k++){n.push('<div style="position:absolute;z-index:1;top:'+p+"px;left:"+q+"px;height:"+(c.direction=="vertical"?"100%":m+"px")+";width:"+(c.direction=="vertical"?r+"px":"100%")+";background-color:rgb("+s[k][0]+","+s[k][1]+","+s[k][2]+');"></div>');c.direction=="vertical"?q+=r:p+=m;if(p>=t||q>=g){break}}n.push("</div>");if(o.css("position")=="static"){o.css("position","relative")}o.html('<div style="display:'+o.css("display")+'; position: relative; z-index: 2;">'+this.innerHTML+"</div>").prepend(n.join(""))})}})(jQuery);