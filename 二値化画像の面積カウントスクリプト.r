# 必要なパッケージ
library(EBImage)

# フォルダ名と画像枚数を交互に定義
path <- "処理するフォルダの場所を指定"
folders <- list.files(path)

# 結果を格納するデータフレーム
all_results <- data.frame(
  Folder = character(),
  Pair = character(),
  Total_Pixels = integer(),
  Only1_White = integer(),
  Only2_White = integer(),
  Both_White = integer(),
  stringsAsFactors = FALSE
)

# 各フォルダを順番に処理
for (folder in folders) {
  id <- 1
  iCont=FALSE
  print(paste("処理中：",folder))
  repeat {
    # 連番ファイル名を作成
    file1 <- file.path(path, folder, sprintf("2nd_Mask-%d-1.tif", id))
    file2 <- file.path(path, folder, sprintf("2nd_Mask-%d-2.tif", id))
    
    # どちらかのファイルが存在しなければループ終了
    if (!file.exists(file1) || !file.exists(file2)) { # ファイルが無くて解析できない
      if(id>12){ # idが大きすぎるときは次のフォルダに移る
        break
      }else{ # idが大きくないときは、次のファイルに移る
        id<-id+1
        next
      }
    }
    
    # 画像を読み込み（InversedLUTとなっているため）
    img1 <- readImage(file1) < 0.5
    img2 <- readImage(file2) < 0.5
    
    # 左上の1ピクセルは無視
    img1[1] <- FALSE
    img2[1] <- FALSE
    
    # それぞれの画像を作る
    only1_white <- img1 & !img2
    only2_white <- !img1 & img2
    both_white  <- img1 & img2
    
    # マスをカウント
    count_only1 <- sum(only1_white)
    count_only2 <- sum(only2_white)
    count_both  <- sum(both_white)
    
    total_pixels_1 <- length(img1)-1 # 左上の1ピクセル分だけ引いておく
    total_pixels_2 <- length(img2)-1 # 左上の1ピクセル分だけ引いておく
    if(total_pixels_1 != total_pixels_2){
      print(paste("pixel数が異なります",total_pixels_1,":",total_pixels_2,":",folder,id))
      exit
    }
    
    # 結果を記録
    all_results <- rbind(all_results, data.frame(
      Folder = folder,
      Pair = id,
      Total_Pixels = total_pixels_1,
      Only1_White = count_only1,
      Only2_White = count_only2,
      Both_White = count_both
    ))
    
    # 次の画像へ
    id <- id + 1
  }
}

# 結果をCSV出力
output_file <- file.path(path, "results.csv")
write.csv(all_results, output_file, row.names = FALSE)

cat(sprintf("すべてのフォルダの結果を %s に保存しました。\n", output_file))

