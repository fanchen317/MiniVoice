package com.xcosmos.minivoice;

public final class StyleFragmentMotionTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        for(float[] size:new float[][]{{360,800},{800,360},{1280,900}}){
            float width=size[0],height=size[1],ox=36,oy=60;
            int columns=StyleFragmentMotion.columns(width),rows=StyleFragmentMotion.rows(height);
            check(columns>=6&&columns<=16&&rows>=6&&rows<=14,"bounded cell count");
            for(int row=0;row<rows;row++)for(int column=0;column<columns;column++){
                float x=(column+.5f)*width/columns,y=(row+.5f)*height/rows,last=0;
                check(StyleFragmentMotion.progress(0,x,y,ox,oy,width,height)==0,"old page intact on first frame");
                for(int ms=0;ms<=680;ms+=10){
                    float p=StyleFragmentMotion.progress(ms,x,y,ox,oy,width,height),e=StyleFragmentMotion.eased(p);
                    check(p>=last&&p<=1&&e>=0&&e<=1,"bounded monotonic motion");last=p;
                }
                check(last==1,"every fragment disappears by 680 ms");
            }
            check(StyleFragmentMotion.progress(100,ox,oy,ox,oy,width,height)>StyleFragmentMotion.progress(100,width,height,ox,oy,width,height),"sweep propagates out from icon");
        }
        check(Math.abs(StyleFragmentMotion.progress(240,36,60,36,60,360,800)-.5f)<.0001,"Mac 480 ms local duration");
        check(StyleFragmentMotion.columns(800)==12&&StyleFragmentMotion.rows(360)==6,"Mac 72 dp cell grid");
        System.out.println("PASS: Mac fragment grid, origin wave, 480 ms local motion and 680 ms completion across phone/tablet orientations");
    }
}
