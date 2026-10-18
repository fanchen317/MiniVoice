export function popoverPosition(anchor,panel,viewport,{above=false,align='start',gap=6}={}){
  const clamp=(value,size,limit)=>Math.max(8,Math.min(limit-size-8,value));
  const below=anchor.bottom+gap,over=anchor.top-panel.height-gap;
  const preferAbove=above?over>=8:below+panel.height>viewport.height-8&&over>=8;
  const x=align==='end'?anchor.right-panel.width:align==='center'?(anchor.left+anchor.right-panel.width)/2:anchor.left;
  return {left:clamp(x,panel.width,viewport.width),top:clamp(preferAbove?over:below,panel.height,viewport.height)};
}
