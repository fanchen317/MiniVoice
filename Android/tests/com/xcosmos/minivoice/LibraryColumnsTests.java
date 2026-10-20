package com.xcosmos.minivoice;

public final class LibraryColumnsTests {
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args){
        for(float density:new float[]{1,2,3.5f})for(int width:new int[]{320,393,559,560,620,759,760,1024,1600}){
            LibraryColumns c=new LibraryColumns(width*density,density);
            check((c.artist>0)==(width>=560),"artist column breakpoint");
            check((c.album>0)==(width>=760),"album column breakpoint");
            check(c.artist+c.album+236*density<width*density,"metadata never consumes the title column");
            check(c.artist<=180*density+1&&c.album<=240*density+1,"columns remain readable and bounded on tablets");
        }
        System.out.println("PASS: adaptive library columns preserve song title space across phone, landscape and tablet widths");
    }
}
