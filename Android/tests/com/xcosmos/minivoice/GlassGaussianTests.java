package com.xcosmos.minivoice;

import java.util.Arrays;

public final class GlassGaussianTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        for(int color:new int[]{0xFF000000,0xFFFFFFFF,0xFF243D32,0xFFEAF4EF}){
            int[] image=new int[9*7];Arrays.fill(image,color);
            for(int pixel:GlassGaussian.blur(image,9,7))check(pixel==color,"Uniform scene changed or gained a dark border");
        }
        int[] step=new int[41];Arrays.fill(step,0,20,0xFF000000);Arrays.fill(step,20,41,0xFFFFFFFF);
        int[] blurred=GlassGaussian.blur(step,41,1);
        check((blurred[19]&255)>0&&(blurred[20]&255)<255,"Scene boundary must actually blur");
        check(blurred[0]==0xFF000000&&blurred[40]==0xFFFFFFFF,"Distant scene colours must survive");
        check(step[19]==0xFF000000&&step[20]==0xFFFFFFFF,"Blur mutated its input");
        int[] checks=new int[32*32];for(int y=0;y<32;y++)for(int x=0;x<32;x++)checks[y*32+x]=(x+y)%2==0?0xFF000000:0xFFFFFFFF;
        int[] soft=GlassGaussian.blur(checks,32,32);
        check(Math.abs((soft[16*32+16]&255)-(soft[16*32+17]&255))<5,"Fine text-like detail must be softened");
        check(GlassGaussian.blur(new int[]{0xFF62AF91},1,1)[0]==0xFF62AF91,"One-pixel fallback failed");
        System.out.println("PASS: Gaussian softens scene/text edges, preserves constant colours and source data, handles narrow snapshots without dark borders");
    }
}
