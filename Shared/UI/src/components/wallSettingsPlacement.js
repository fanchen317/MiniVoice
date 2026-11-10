/** Portrait width, with the right corners spanning the search and settings controls. */
export function wallSettingsPlacement({width,height,padding,anchor,search,gap=12}){
 const {top=12,right=12,bottom=12,left=12}=padding||{};
 const panelWidth=Math.max(1,Math.min(560,Math.min(width,height)-2*gap,width-left-right));
 const edgeRight=Math.max(0,right-gap,Math.min(width-Math.max(0,left-gap)-panelWidth,width-(anchor?.right??width-right)));
 const edgeBottom=Math.max(bottom,Math.min(height-top-1,height-(anchor?.bottom??height-bottom)));
 const edgeTop=Math.min(height-edgeBottom-1,Math.max(0,top-gap,search?.top??top));
 const panelHeight=Math.max(1,height-edgeBottom-edgeTop);
 return {width:panelWidth,right:edgeRight,bottom:edgeBottom,height:panelHeight,maxHeight:panelHeight};
}
