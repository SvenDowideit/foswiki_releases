jQuery.fn.popupwindow=function(b){var a=b||{};return this.each(function(g){var j,k,e,d,f,c;e=(jQuery(this).attr("rel")||"").split("|");j={height:600,width:600,toolbar:0,scrollbars:0,status:0,resizable:1,left:0,top:0,center:0,createnew:1,location:0,menubar:0,onUnload:null};if(e.length==1&&e[0].split(":").length==1){f=e[0];if(typeof a[f]!="undefined"){j=jQuery.extend(j,a[f])}}else{for(var h=0;h<e.length;h++){d=e[h].split(":");if(typeof j[d[0]]!="undefined"&&d.length==2){j[d[0]]=d[1]}}}if(j.center==1){j.top=(screen.height-(j.height+110))/2;j.left=(screen.width-j.width)/2}k="location="+j.location+",menubar="+j.menubar+",height="+j.height+",width="+j.width+",toolbar="+j.toolbar+",scrollbars="+j.scrollbars+",status="+j.status+",resizable="+j.resizable+",left="+j.left+",screenX="+j.left+",top="+j.top+",screenY="+j.top;jQuery(this).bind("click",function(){var i=j.createnew?"PopUpWindow"+g:"PopUpWindow";c=window.open(this.href,i,k);if(j.onUnload){unloadInterval=setInterval(function(){if(!c||c.closed){clearInterval(unloadInterval);j.onUnload.call($(this))}},500)}c.focus();return false})})};