foswiki.Array={remove:function(a,b){if(!a||!b){return null}for(i=0;i<a.length;i++){if(b==a[i]){a.splice(i,1)}}},convertArgumentsToArray:function(d,a){if(d==undefined){return null}var c=d.length;if(c==0){return null}var f=0;if(a){if(isNaN(a)){return null}if(a>c-1){return null}f=a}var e=[];for(var b=f;b<c;b++){e.push(d[b])}return e},indexOf:function(d,c){if(!d||d.length==undefined){return null}var b,a=d.length;for(b=0;b<a;++b){if(d[b]==c){return b}}return -1}};