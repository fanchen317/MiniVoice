// Tab belongs to form editing. Poster cards, navigation and playback actions
// remain mouse / dedicated-shortcut controls rather than stops in a key loop.
export function textInputTabNavigation(event){
  if(event.metaKey||event.ctrlKey||event.altKey)return;
  event.preventDefault();
  const scope=document.querySelector('[role="dialog"],.modal-backdrop')||document;
  const fields=[...scope.querySelectorAll('input,textarea,[contenteditable="true"]')].filter(node=>
    !node.disabled&&!node.readOnly&&!node.closest('[inert],[aria-hidden="true"]')&&
    node.getClientRects().length&&getComputedStyle(node).visibility!=='hidden'&&
    (node.tagName!=='INPUT'||!['hidden','range','checkbox','radio','button','submit','reset','file','color','image'].includes(node.type)));
  if(!fields.length){document.activeElement?.blur();return;}
  const index=fields.indexOf(document.activeElement),backwards=event.shiftKey;
  fields[index<0?(backwards?fields.length-1:0):(index+(backwards?-1:1)+fields.length)%fields.length].focus();
}
