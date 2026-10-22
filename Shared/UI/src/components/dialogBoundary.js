const managers=new WeakMap();
const selector='button,input,select,textarea,a[href],[tabindex],[contenteditable="true"]';
export function focusableWithin(root){return [...root.querySelectorAll(selector)].filter(node=>!node.disabled&&node.tabIndex>=0&&!node.closest('[hidden],[inert],[aria-hidden="true"]')&&node.getClientRects().length);}
/** Shared dialog ownership: only the top layer receives shortcuts or restores focus. */
export function bindDialog(root,{onClose,background,initialFocus='dialog'}={}){
 const doc=root.ownerDocument,win=doc.defaultView;let manager=managers.get(doc);
 if(!manager){manager={layers:[],backgrounds:new Map()};managers.set(doc,manager);}
 const previous=doc.activeElement,entry={root,previous};
 if(background){const saved=manager.backgrounds.get(background);if(saved)saved.count++;else manager.backgrounds.set(background,{count:1,inert:background.inert});background.inert=true;}
 for(const layer of manager.layers)layer.root.inert=true;manager.layers.push(entry);
 const first=initialFocus==='field'?focusableWithin(root).find(node=>node.matches('input:not([type=checkbox]):not([type=range]),textarea,[contenteditable="true"]')):null;
 (first||root).focus({preventScroll:true});
 const key=event=>{
  if(manager.layers.at(-1)!==entry)return;
  // Ordinary keys must reach self-rendered controls (sliders, editors).
  // Host shortcut handlers exclude aria-modal content; only layer navigation is captured here.
  if(event.key!=='Escape'&&event.key!=='Tab')return;
  event.stopImmediatePropagation();
  if(event.key==='Escape'){event.preventDefault();onClose?.();}
  if(event.key==='Tab'){
   const nodes=focusableWithin(root),index=nodes.indexOf(doc.activeElement);
   if(!nodes.length){event.preventDefault();root.focus({preventScroll:true});}
   else if(index<0||event.shiftKey&&index===0||!event.shiftKey&&index===nodes.length-1){event.preventDefault();nodes[event.shiftKey?nodes.length-1:0].focus({preventScroll:true});}
  }
 };
 const focus=event=>{if(manager.layers.at(-1)===entry&&!root.contains(event.target))root.focus({preventScroll:true});};
 win.addEventListener('keydown',key,true);doc.addEventListener('focusin',focus,true);
 return()=>{
  const top=manager.layers.at(-1)===entry;win.removeEventListener('keydown',key,true);doc.removeEventListener('focusin',focus,true);manager.layers=manager.layers.filter(layer=>layer!==entry);
  if(background){const saved=manager.backgrounds.get(background);if(saved&&!--saved.count){background.inert=saved.inert;manager.backgrounds.delete(background);}}
  if(manager.layers.length)manager.layers.at(-1).root.inert=false;
  if(top&&previous?.isConnected&&!previous.closest('[inert]'))previous.focus({preventScroll:true});
 };
}
