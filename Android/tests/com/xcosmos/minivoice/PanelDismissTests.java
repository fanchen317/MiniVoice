package com.xcosmos.minivoice;

public final class PanelDismissTests {
    public static void main(String[] args){
        check(!PanelDismiss.shouldClose(0,2000,800,1),"tap must not dismiss");
        check(!PanelDismiss.shouldClose(30,0,800,1),"short drag returns");
        check(PanelDismiss.shouldClose(130,0,800,1),"long drag dismisses");
        check(PanelDismiss.shouldClose(20,1000,800,1),"outward fling dismisses");
        check(!PanelDismiss.shouldClose(130,-1000,800,1),"reverse fling returns");
        check(PanelDismiss.shouldClose(80,0,300,1),"drawer uses its own width");
        check(!PanelDismiss.shouldClose(20,1000,1600,2),"thresholds respect density");
        System.out.println("Panel dismissal tests passed");
    }
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
}
