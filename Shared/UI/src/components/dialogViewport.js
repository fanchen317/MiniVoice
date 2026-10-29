/** Layout coordinates for a fixed dialog when the keyboard shrinks only the visual viewport. */
export function dialogViewport(layoutHeight,visual,keyboardInset=0){
 const full=Number.isFinite(layoutHeight)&&layoutHeight>0?layoutHeight:1;
 const top=Math.min(full-1,Math.max(0,Number(visual?.offsetTop)||0));
 const available=Math.max(1,full-Math.max(0,Number(keyboardInset)||0)-top);
 const height=Math.min(available,Math.max(1,Number(visual?.height)||full));
 return {top,height,keyboard:full-top-height>80};
}
