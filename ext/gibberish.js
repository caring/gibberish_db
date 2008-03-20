/* Probably a good idea to only include this based on user permissions */

/* don't escape the html coming from server */
Object.extend(Ajax.InPlaceEditor.prototype, {
    onLoadedExternalText: function(transport) {
        Element.removeClassName(this.form, this.options.loadingClassName);
        this.editField.disabled = false;
        this.editField.value = transport.responseText;
        Field.scrollFreeActivate(this.editField);
    }
});

Object.extend(Ajax.InPlaceEditor.prototype, {
    getText: function() {
        return this.element.childNodes[0] ? this.element.childNodes[0].nodeValue : '';
    }
});

/* Edit the gibberish string in a popup because not all gibberish strings are clickable. Uses http://www.methods.co.nz/popup/popup.html */
function createGibberishPopup(translated_element,key) {
  var popup = document.createElement('div')
  popup.setAttribute('id','popup_'+key)
  popup.setAttribute('style','style:display: none; width: 270px;')
  popup.setAttribute('class','popup')
  popup = $(popup)
  document.body.appendChild(popup);
  popup.update('Edit: <span class="editable">'+translated_element.innerHTML+'</span>')
  var editor = popup.getElementsByClassName("editable").first()
  new Ajax.InPlaceEditor( editor, '/gibberish/save/'+key+"?lang="+translated_element.lang, {
    rows: 3,
    'loadTextURL' : '/gibberish/edit/'+key+"?lang="+translated_element.lang,
    onComplete: function(transport, element) {
      translated_element.update(element.innerHTML);
      new Effect.Highlight(element, {startcolor: "#FFFF00"});
      new Effect.Highlight(translated_element, {startcolor: "#FFFF00"});
    }
  });
  return popup;
}

/* Press CTRL-E to enable string editing. The editable css class gets applied at that time so you can
   make them visually distinctive */
function make_strings_editable(event)
{ 
  if(event.ctrlKey && event.charCode == 101) {
    $$(".translated").each(function(translated_element) {
      if (!translated_element.hasClassName("editable")) {
        translated_element.addClassName("editable");
        var key = translated_element.className.split(/ +/).map(function(cn){
          if (cn.match(/^key_/)) { return cn.sub(/^key_/,"")} else {return}
        }).compact().first();
        var parent_link = translated_element.up("a");
        if (parent_link) {
          var popup = createGibberishPopup(translated_element,key)
          new Popup(popup,parent_link,{position:'below', trigger:'mouseover', show_duration: 0})
        } else {
          new Ajax.InPlaceEditor( translated_element, '/gibberish/save/'+key+"?lang="+translated_element.lang, {highlight: false, rows: 3, 'loadTextURL' : '/gibberish/edit/'+key+"?lang="+translated_element.lang});
        }
      }
    });
  }
}

Event.observe(window, 'keypress', make_strings_editable);