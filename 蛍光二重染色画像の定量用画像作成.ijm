//2026/04/04版
//画像名はaaa#nn.tifである必要があります。例：amyloidB#01.tif
//また画像は2ch画像である必要があります。

// 実行方法：画像を開く⇒imagej/Fijiでマクロ実行
// 処理内容：構造物をROIで指定⇒ch1でしきい値選択⇒ch2でしきい値選択



getDimensions(iwidth,iheight,ich,islices,iframes);
if(ich!=2){
	exit("ch数が"+ich+"です\n手動でDeleteSliceしてください\n終了します");
}

// 1. タイトルからsampNoを取得
title = getTitle();
f_one_sample=false;
//   f_one_sample=true;
if(!f_one_sample){//サンプル名を1にするとき
	parts = split(title, "#");//ABC#01.tifから01を抽出
	parts2=split(parts[1],".");
	sampNo = parts2[0]; 
}else{
	sampNo=1;waitForUser("サンプル名を強制的に1にします");
}

curDir=getDir("image");

// 2. original として画像を取得
rename("original");
Stack.setDisplayMode("grayscale");

// 3. チャンネルを分離（Image is assumed to be composite with 2 channels）
run("Split Channels");
// C1-original.tif, C2-original.tif が生成される前提

// 4. ROI選択（ch2にフォーカス）
roiManager("reset");
run("ROI Manager...");
run("Brightness/Contrast...");


selectWindow("C2-original");
waitForUser("構造物のROIを選択し、tで登録してください\n"+sampNo);
run("Select None");

// ch1とch2両方にROI適用して黒で塗りつぶし
for (ch = 1; ch <= 2; ch++) {
	
	selectWindow("C" + ch + "-original");
	run("Duplicate...", "title=C"+ch+"-mask-tmp");wait(300);
    
    run("Gaussian Blur...", "sigma=2");//ぼかし
    run("Subtract Background...", "rolling=200");
    roiCount = roiManager("count");
    setColor(0, 0, 0); // 黒

    for (i = 0; i < roiCount; i++) {
        roiManager("Select", i);
        run("Fill");
    }
    run("Select None");
}
if(roiCount>0){
	roiManager("Save", curDir + "ROI-"+sampNo + ".zip");
}
roiManager("reset");

// 5. ch1とch2でしきい値選択、テキストで保存
thresholdInfo = "C1-low,C1-upper,C2-low,C2-upper\n";
for (ch = 1; ch <= 2; ch++) {
	win="C" + ch + "-mask-tmp";
    selectWindow(win);
	wait(100);
    //setAutoThreshold("Default dark no-reset");
	run("Threshold...");
	//run("Brightness/Contrast...");
	origTitle = getTitle();
	
	setThreshold(2000,65535);
    waitForUser("しきい値を選択してください");
    getThreshold(lower, upper);
    waitForUser("lower="+lower+" upper="+upper);
    thresholdInfo = thresholdInfo+ lower + "," + upper+",";

    run("Analyze Particles...", "size=12-Infinity pixel show=Masks include");//exclude
    selectWindow("Mask of C"+ch+"-mask-tmp");


    rename("C"+ch+"-inverted-mask");
    run("Duplicate...", "title=C"+ch+"-mask");wait(300);
    selectWindow("C"+ch+"-mask");
    run("Invert");
    //run("Convert to Mask");
    run("Close-");run("Close-");run("Close-");
    run("16-bit");
    run("Multiply...","value=257");
    selectWindow("C"+ch+"-inverted-mask");
    run("16-bit");
    run("Multiply...","value=257");

}
File.saveString(thresholdInfo, curDir + "Thr-"+sampNo + ".csv");
// ファイル保存（しきい値）

devvalue=8;//見やすくする

//C1,C2,none
for(ch=1;ch<=2;ch++){
	//mon1:オリジナル画像
	selectWindow("C"+ch+"-original");wait(100);
	run("Duplicate...", "title=mon"+ch+"1");wait(300);
	//mon2:採用箇所
	imageCalculator("AND create", "C"+ch+"-original", "C"+ch+"-inverted-mask");wait(300);
	saveAs("Tiff",curDir+"Cut-"+sampNo+"-"+ch+".tif");wait(300);
	rename("mon"+ch+"2");wait(100);
	//mon3:非-採用箇所
	imageCalculator("AND create", "C"+ch+"-original", "C"+ch+"-mask");wait(300);
	rename("mon"+ch+"3");wait(100);
	//mon4:採用マスク
	selectWindow("C"+ch+"-mask");wait(100);
	run("Duplicate...", "title=mon"+ch+"4");wait(300);
	saveAs("Tiff",curDir+"Mask-"+sampNo+"-"+ch+".tif");wait(300);
	rename("mon"+ch+"4");wait(100);
	run("Divide...", "value="+devvalue);
	//close("mon"+ch+"4");
	//本当は16-bitで保存する必要ないけど。
	
}

run("Images to Stack", "title=mon use");wait(300);
rename("stack");
run("Make Montage...", "columns=4 rows=2 scale=0.25 title=Montage");wait(300);
run("Enhance Contrast", "saturated=0.05");
selectWindow("Montage");
saveAs("Tiff",curDir+"Mon-"+sampNo+".tif");
// 現在開かれているウィンドウ一覧を取得
windows = getList("image.titles");
// originalという名前のウィンドウは閉じず、それ以外を閉じる
for (i = 0; i < windows.length; i++) {
    firstChar=substring(windows[i],0,1);
    if(firstChar>="0"&&firstChar<="9"){
    	continue;
    }
    if(firstChar=="M"){
    	continue;
    }
    selectWindow(windows[i]);
    close();
}


