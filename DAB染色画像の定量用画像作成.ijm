//DAB染色画像の面積定量imageJ/Fijiマクロ
//使い方：
//画像を開く
//矩形でスライド外の空白領域を選択する（ここで選択した領域のy座標が使われる。このy軸の範囲を背景として認識し、画像全体から引き算して、スキャンによる縦じま模様をキャンセルする）
//imagejマクロを起動する。


//処理(1)ファイルを背景補正
//処理(2)ROIを手動設定
//処理(3)color DeconvolutionによってDAB成分のみ取り出し
//処理(4)閾値設定
//処理(5)処理の可視化画像を生成

//背景補正有無を決定、バックグラウンドに縦じまがあるようなときに実施
//きれいな背景部分が無いようなときは背景補正無しに切り替えてください。
correct=true;//背景補正あり
//correct=false;//背景補正無し



//******************
//以下は触らないでください。
//******************

// 処理(0)前処理
getDimensions(iwidth,iheight,ich,islices,iframes);
title = getTitle();
curDir=getDir("image");

// 背景除去
run("ROI Manager...");

if(!File.exists(curDir + title + "-bg.csv")){// 初めての時
	waitForUser("select background");
	getSelectionBounds(roiX, roiY, roiW, roiH);
	background_text=" " + roiY + "," + roiH;
	File.saveString(background_text, curDir + title + "-bg.csv");
}else{// もう背景データがあるとき
	text=File.openAsString(curDir + title + "-bg.csv");
	cols=split(text,",");
	roiY=parseInt(cols[0]);
	roiH=parseInt(cols[1]);
}
if(roiH>3000){
	//縦にROIが長すぎるので、これはROI未選択のときに違いない
	//補正はしない方向に処理ルートを切り替える
	waitForUser(roiH+":"+iheight+"\nおそらく補正無し");
	correct=false;
}

smoothRadius=10;
run("Select None");
run("Duplicate...", "title=Work_RGB");wait(300);
run("Split Channels");
redTitle   = "Work_RGB (red)";
greenTitle = "Work_RGB (green)";
blueTitle  = "Work_RGB (blue)";

//処理(1)背景補正

function correctChannel(srcTitle, outTitle, roiY, roiH, smoothRadius) {
    selectWindow(srcTitle);
    run("32-bit");
    getDimensions(w, h, c, z, t);

    // ROIのy範囲だけを使って、各x列の背景値を計算する
    // 横方向はROI幅に制限せず、画像全幅で計算する
    newImage("Profile_" + srcTitle, "32-bit black", w, 1, 1);

    bgSum = 0;
	setBatchMode(true);
    for (x = 0; x < w; x++) {
        selectWindow(srcTitle);

        sum = 0;
        n = 0;

        for (y = roiY; y < roiY + roiH; y++) {
            if (y >= 0 && y < h) {
                sum += getPixel(x, y);
                n++;
            }
        }

        mean = sum / n;
        bgSum += mean;

        selectWindow("Profile_" + srcTitle);
        setPixel(x, 0, mean);
    }
	setBatchMode(false);
    //globalMean = bgSum / w;

    // 1行の横方向プロファイルを画像全体へ縦方向に引き延ばす
    selectWindow("Profile_" + srcTitle);
    run("Size...", "width=" + w + " height=" + h + " depth=1 interpolation=Bilinear");
    rename("Flat_" + srcTitle);

    // 横方向のプロファイルを平滑化
    run("Gaussian Blur...", "sigma=" + smoothRadius);

    // 補正: 元画像 / 縦じま背景 * 背景平均
    //imageCalculator("Divide create 32-bit", srcTitle, "Flat_" + srcTitle);
    selectWindow(srcTitle);
    run("Add...", "value=" + 255);
    imageCalculator("Subtract create 32-bit", srcTitle, "Flat_" + srcTitle);
    
    rename("Div_" + srcTitle);

    //run("Multiply...", "value=" + globalMean);

    setMinAndMax(0, 255);
    run("16-bit");
    rename(outTitle);

    // 中間画像を閉じる
    //selectWindow("Profile_" + srcTitle); close();
    selectWindow("Flat_" + srcTitle); close();
    //selectWindow("Div_" + srcTitle); close();

    selectWindow(srcTitle); close();
}


// 各チャンネル補正

if(correct){
	//補正するとき
	correctChannel(redTitle,   "Corr_R", roiY, roiH, smoothRadius);
	correctChannel(greenTitle, "Corr_G", roiY, roiH, smoothRadius);
	correctChannel(blueTitle,  "Corr_B", roiY, roiH, smoothRadius);
}else{
	//補正しないとき
	//waitForUser("補正無し");
	function cC(srcTitle, outTitle){
		selectWindow(srcTitle);
		run("Duplicate...", "title="+outTitle);
		close(srcTitle);
	}
	cC(redTitle,"Corr_R");
	cC(greenTitle,"Corr_G");
	cC(blueTitle,"Corr_B");
}

// RGBに戻す
run("Merge Channels...", "c1=Corr_R c2=Corr_G c3=Corr_B create");
run("RGB Color");
rename("merged_RGB");
saveAs("Tiff",curDir+"step1.tif");rename("merged_RGB");


// 処理(2)ROI手動設定
roiManager("reset");run("Select None");
run("ROI Manager...");
if(!File.exists(curDir + title + "-ROI.zip")){// 初めての時
	waitForUser("select ROI & press T key\ntitle="+title);
	//ROIを保存する
	roiManager("Save", curDir + title + "-ROI.zip");
}else{
	//すでにROIがあれば、そちらを使う
	open(curDir + title + "-ROI.zip");
}




roiManager("Select",0);
run("Duplicate...", "title=trimed_merged_rgb");wait(300);
selectWindow("merged_RGB");roiManager("Select", 0);
run("Duplicate...", "title=processing");wait(300);
run("Colors...", "foreground=black background=white selection=yellow");
run("Clear Outside");

run("Duplicate...", "title=mask");wait(300);
selectWindow("mask");
run("Colors...", "foreground=black background=white selection=yellow");
run("Fill");
run("Clear Outside");
run("8-bit");
saveAs("Tiff",curDir + title + "-ROImask.tif");
rename("ROImask");run("RGB Color");


// 処理(3)Color Deconvolution

selectWindow("processing");
run("Colour Deconvolution", "vectors=[H DAB]");
//close("processing-(Colour_1)");
//close("processing-(Colour_3)");
close("Colour deconvolution");

// 処理(4)閾値設定
run("Threshold...");
selectWindow("processing-(Colour_2)");
saveAs("Tiff", curDir+title+"-preprocess.tif");
rename("processing-(Colour_2)");
setThreshold(0,140);//default値を入れている
waitForUser("しきい値を選択してください");
selectWindow("processing-(Colour_2)");
getThreshold(lower, upper);
waitForUser("しきい値\n" + lower + "～" + upper);

// どのような閾値で処理したか、テキストに保存する
thresholdInfo = "lower,upper\n" + lower + "," + upper;
File.saveString(thresholdInfo, curDir + title + "-thr.csv");

//粒子検出
run("Analyze Particles...", "size=15-Infinity pixel show=Masks");
selectWindow("Mask of processing-(Colour_2)");
run("8-bit");
//マスク作成
saveAs("Tiff",curDir + title + "-mask.tif");
rename("mask");run("RGB Color");


// 処理(5)処理の可視化画像を生成


// 5-1. exclude part
imageCalculator("AND create","ROImask","trimed_merged_rgb");wait(300);
rename("mon-tmp");

// 5-2. include part
selectWindow("ROImask");
roiManager("reset");run("Select None");
run("Invert");
imageCalculator("AND create","ROImask","trimed_merged_rgb");wait(300);
rename("mon-1");

selectWindow("mon-tmp");
run("Duplicate...", "title=mon-2");close("mon-tmp");wait(300);

// 5-3. exclude part
imageCalculator("AND create","mask","trimed_merged_rgb");wait(300);
rename("mon-3");

// 5-4. include part
selectWindow("mask");
roiManager("reset");run("Select None");
run("Invert");
imageCalculator("AND create","mask","trimed_merged_rgb");wait(300);
rename("mon-4");

// 5-5. make montage
run("Images to Stack", "title=mon use");wait(300);
rename("stack");
run("Make Montage...", "columns=2 rows=2 scale=0.5 title=montage");wait(300);
selectWindow("Montage");
saveAs("Tiff",curDir + title + "-mon.tif");
rename("montage");


// 6. close
windows = getList("image.titles");
for (i = 0; i < windows.length; i++) {
    if(windows[i]==title||windows[i]=="montage"){
    	continue;
    }
    selectWindow(windows[i]);
    close();
}
waitForUser("complete");

close("montage");
close(title);
