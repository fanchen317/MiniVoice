package com.xcosmos.minivoice;

public final class WallViewportTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        for(float density:new float[]{1,2,2.75f,3})for(float shortSide:new float[]{360,393,430}){
            float portraitDock=(shortSide-32)*density;
            WallViewport portrait=new WallViewport(shortSide*density,850*density,density,0,24*density,0,24*density,false,portraitDock);
            WallViewport landscape=new WallViewport(850*density,shortSide*density,density,28*density,0,0,0,true,portrait.dockWidth);
            check(Math.abs(landscape.dockWidth-portrait.dockWidth)<.01f,"rotation must preserve portrait dock width");
            float dockLeft=landscape.width-landscape.dockRight-landscape.dockWidth;
            check(landscape.focusX+landscape.focusSide/2<dockLeft,"focused card must remain left of dock area");
            check(landscape.focusY-landscape.focusSide/2>=0,"focused card top clipped");
            check(landscape.focusY+landscape.focusSide/2<=landscape.height,"focused card bottom clipped");
            check(landscape.focusX<landscape.width/2,"landscape focus belongs on the left");
            check(landscape.dockBottom==14*density,"landscape bottom safe margin");
        }
        System.out.println("PASS: portrait-size landscape dock, left centered focus, cutout spacing and unclipped cards across densities");
    }
}
