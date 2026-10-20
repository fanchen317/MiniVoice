package com.xcosmos.minivoice;

public final class ArtworkFramingTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    private static void near(float a,float b){check(Math.abs(a-b)<.02f,a+" != "+b);}
    public static void main(String[] args){
        for(float[] image:new float[][]{{1600,1600},{1800,900},{900,1800},{300,300}}){
            for(float[] screen:new float[][]{{393,852},{852,393},{600,900},{900,600}}){
                float regionWidth=screen[0]>screen[1]?ArtworkFraming.landscapeSplit(screen[0],28,16)-28:screen[0]-44;
                ArtworkFraming.Plan p=ArtworkFraming.plan(image[0],image[1],28,0,regionWidth,screen[1]);
                check(p.x>=28-.01f&&p.y>=-.01f&&p.x+p.width<=28+regionWidth+.01f&&p.y+p.height<=screen[1]+.01f,"artwork remains inside its pane");
                check(p.sourceX>=0&&p.sourceY>=0&&p.sourceX+p.sourceWidth<=image[0]+.01f&&p.sourceY+p.sourceHeight<=image[1]+.01f,"valid source crop");
                near(p.width/p.height,p.sourceWidth/p.sourceHeight);
                if(p.contained){near(p.sourceWidth,image[0]);near(p.sourceHeight,image[1]);near(p.sourceX,0);near(p.sourceY,0);}
                else check(p.sourceWidth*p.sourceHeight/(image[0]*image[1])>=.8999f,"crop loss is at most ten percent");
            }
        }
        check(ArtworkFraming.plan(1600,1600,0,0,393,852).contained,"portrait expansion preserves full square composition");
        check(!ArtworkFraming.plan(1600,1600,0,0,393,400).contained,"similar aspect ratios may fill without large cropping");
        for(int percent=60;percent<=120;percent+=5){ArtworkFraming.Plan p=ArtworkFraming.plan(1600,1600,0,0,393,852);near(p.sourceWidth,1600);near(p.width,393);}
        System.out.println("PASS: expanded artwork preserves composition across portrait/landscape, bounds crop loss and does not depend on wall zoom");
    }
}
