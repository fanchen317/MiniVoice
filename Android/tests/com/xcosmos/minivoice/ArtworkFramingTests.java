package com.xcosmos.minivoice;

public final class ArtworkFramingTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    private static void near(float a,float b){check(Math.abs(a-b)<.02f,a+" != "+b);}
    private static boolean contains(ArtworkFraming.Plan p,ArtworkFraming.Face f,float iw,float ih){return p.sourceX<=f.left*iw+.02f&&p.sourceY<=f.top*ih+.02f&&p.sourceX+p.sourceWidth>=f.right*iw-.02f&&p.sourceY+p.sourceHeight>=f.bottom*ih-.02f;}
    public static void main(String[] args){
        ArtworkFraming.Face left=new ArtworkFraming.Face(.04f,.2f,.22f,.5f,.95f);
        ArtworkFraming.Plan portrait=ArtworkFraming.plan(1600,1600,0,0,393,852,new ArtworkFraming.Face[]{left});
        check(contains(portrait,left,1600,1600),"off-center face remains complete in portrait crop");
        near(portrait.width,393);near(portrait.height,852);near(portrait.sourceWidth/portrait.sourceHeight,393f/852);
        ArtworkFraming.Face top=new ArtworkFraming.Face(.3f,.02f,.6f,.22f,.9f);
        ArtworkFraming.Plan landscape=ArtworkFraming.plan(1600,1600,0,0,852,393,new ArtworkFraming.Face[]{top});check(contains(landscape,top,1600,1600),"landscape crop retains forehead and chin");
        ArtworkFraming.Face a=new ArtworkFraming.Face(.2f,.2f,.3f,.45f,.9f),b=new ArtworkFraming.Face(.5f,.2f,.6f,.45f,.9f);
        ArtworkFraming.Plan group=ArtworkFraming.plan(1600,1600,0,0,393,852,new ArtworkFraming.Face[]{a,b});check(contains(group,a,1600,1600)&&contains(group,b,1600,1600),"multiple faces retained when geometry permits");
        ArtworkFraming.Face wideA=new ArtworkFraming.Face(.15f,.25f,.4f,.55f,.95f),wideB=new ArtworkFraming.Face(.6f,.25f,.85f,.55f,.95f);
        ArtworkFraming.Plan wide=ArtworkFraming.plan(1600,1600,0,0,800,1600,new ArtworkFraming.Face[]{wideA,wideB});
        check(wide.sourceX<.4f*1600&&wide.sourceX+wide.sourceWidth>.6f*1600,"wide group shares crop loss instead of removing one person");
        near(wide.sourceX,400);
        for(float[] image:new float[][]{{1600,1600},{1800,900},{900,1800}})for(float[] screen:new float[][]{{393,852},{852,393},{600,900}}){
            ArtworkFraming.Plan p=ArtworkFraming.plan(image[0],image[1],0,0,screen[0],screen[1],new ArtworkFraming.Face[]{left,top,a,b});
            near(p.width,screen[0]);near(p.height,screen[1]);near(p.sourceWidth/p.sourceHeight,screen[0]/screen[1]);
            check(p.sourceX>=-.01f&&p.sourceY>=-.01f&&p.sourceX+p.sourceWidth<=image[0]+.02f&&p.sourceY+p.sourceHeight<=image[1]+.02f,"full-bleed crop remains within original image");
        }
        ArtworkFraming.Plan fallback=ArtworkFraming.plan(1600,1600,0,0,393,852,null);near(fallback.width,393);near(fallback.height,852);
        System.out.println("PASS: full-bleed face-aware crop retains single/group faces when possible, protects top-of-frame faces and has bounded fallback geometry");
    }
}
