package com.xcosmos.minivoice;
import java.io.*;
import java.nio.charset.StandardCharsets;
public final class ProtocolCLI {public static void main(String[] args)throws Exception{BufferedReader input=new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8));for(String line;(line=input.readLine())!=null;)System.out.println(SharedCore.execute(line));}}
