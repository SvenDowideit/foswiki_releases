jQuery(function(a){a(".jqRating:not(.jqInitedRating)").livequery(function(){var d=a(this),c=a.extend({focus:function(h,g){var f=a(g),i=f.attr("title")||f.attr("value");d.find(".jqRatingValue").text(i)},blur:function(h,g){var f=d.find(":checked"),i=f.attr("title")||f.attr("value")||"";d.find(".jqRatingValue").text(i)},callback:function(h,g){var f=a(g),i=f.attr("title")||f.attr("value");d.find(".jqRatingValue").text(i)}},d.metadata()),b=d.find(":checked"),e=b.attr("title")||b.attr("value")||"";a("<span>"+e+"</span>").addClass("jqRatingValue").appendTo(d);d.addClass("jqInitedRating").find("input:[type=radio]").rating(c);d.find(".rating-cancel").hover(function(){if(typeof(c.focus)=="function"){c.focus(0,this)}},function(){if(typeof(c.blur)=="function"){c.blur(0,this)}})})});