//
//  SSImageProcessor.m
//  SudokuSolver
//
//  Created by Denis Lebedev on 3/26/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SSImageProcessor.h"
#import "UIImage+Additions.h"

#ifdef __cplusplus
extern "C" {
#endif
#import "Common.h"
#ifdef __cplusplus
}
#endif

@interface SSImageProcessor () {
    CvPoint sudokuFrame[2];
    IplImage *squares[9][9];
}

@property (nonatomic, retain) UIImage *image;

@property (nonatomic, retain) UIImage *binarizedImage;

- (IplImage *)closeImage:(IplImage *)source;

@end

@implementation SSImageProcessor

@synthesize image = _image;
@synthesize binarizedImage = _binarizedImage;

-(id)initWithImage:(UIImage *)image {
    if (self = [super init]) {
        assert(image);
        self.image = image;
    }
    return self;
}

- (UIImage *)binarizeImage:(UIImage *)source {
    IplImage *img_rgb = [source IplImage];
    IplImage* im_bw = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    AdaptiveThreshold(img_rgb, im_bw, 11);
    
    IplImage* color_dst = cvCreateImage( cvGetSize(im_bw), IPL_DEPTH_8U, 3);
    cvCvtColor(im_bw, color_dst, CV_GRAY2RGB);
    self.binarizedImage = [UIImage imageFromIplImage:color_dst];

    cvReleaseImage(&color_dst);
    cvReleaseImage(&im_bw);
    return self.binarizedImage;
}

- (UIImage *)detectBoundingRectangle:(UIImage *)source {
    IplImage *img_rgb = [source IplImage];
    IplImage *img_gray = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    cvCvtColor(img_rgb, img_gray, CV_RGB2GRAY);
      
    detectSudokuBoundingBox(img_gray, sudokuFrame);
    cvRectangle(img_rgb, sudokuFrame[0], sudokuFrame[1], CV_RGB(0,255,0), 2, CV_AA, 0);
    return [UIImage imageFromIplImage:img_rgb];
    //dealloc iplimages
}


- (IplImage *)closeImage:(IplImage *)source {
    //IplImage *img_gray = cvCreateImage(cvGetSize(source),IPL_DEPTH_8U,1);
    //cvCvtColor(source, img_gray, CV_RGB2GRAY);
    
    int radius = 3;
    IplConvKernel* Kern = cvCreateStructuringElementEx(radius*2+1, radius*2+1, radius, radius, CV_SHAPE_RECT, NULL);
    cvErode(source, source, Kern, 1);
    cvDilate(source, source, Kern, 1);
    

    
    cvReleaseStructuringElement(&Kern);
    
    
    //IplImage* color_dst = cvCreateImage( cvGetSize(source), IPL_DEPTH_8U, 3);
    //cvCvtColor(source, color_dst, CV_GRAY2RGB);

    return source;

//    CvScalar pixel;
//    for (int i = 1; i < img_rgb->height - 1; i++) {
//        for (int j = 1; j < img_rgb->width - 1; j++) {
//            pixel = cvGet2D(img_gray, i, j);
//            
//            if (pixel.val[0] == 0.0) {
//                if (cvGet2D(img_gray, i - 1, j).val[0] == 0.0 && 
//                    cvGet2D(img_gray, i + 1, j).val[0] == 0.0 && 
//                    cvGet2D(img_gray, i, j - 1).val[0] == 0.0 &&
//                    cvGet2D(img_gray, i, j + 1).val[0] == 0.0) {
//                    cvCircle(color_dst, cvPoint(j, i), 2, CV_RGB(255,255,0), 1, CV_AA, 0);
//                }
//            }
//        }
//    }
//
//    UIImage *result = [UIImage imageFromIplImage:color_dst];

//    return result;
}

- (double)imageRotationAngle:(UIImage *)source {
    IplImage *img_rgb = [source IplImage];
    IplImage *img_bw = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    IplImage* dst = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    IplImage* color_dst = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,3);
    
    cvCvtColor(img_rgb, img_bw, CV_RGB2GRAY);
    cvCanny( img_bw, dst, 50, 100, 3 );
    cvCvtColor( dst, color_dst, CV_GRAY2RGB);
    
    CvMemStorage* storage = cvCreateMemStorage(0);
    CvSeq* lines = 0;
    
    lines = cvHoughLines2( dst, storage, CV_HOUGH_PROBABILISTIC, 1, CV_PI/180, 50, 50, 10);
    
    double imageRotationAngle = 0;
    
    for(int i = 0; i < lines->total; i++ ){
        CvPoint* line = (CvPoint*)cvGetSeqElem(lines, i);
        double tempAngle = atan2(line[1].y - line[0].y, line[1].x - line[0].x) * 180.0 / CV_PI;
        if (tempAngle > - 20 && tempAngle < 20 && imageRotationAngle == 0) {
            imageRotationAngle = tempAngle;
        }
    }
    return imageRotationAngle;
}

- (UIImage *)rotateImage:(UIImage *)source {
    double rotationAngle = [self imageRotationAngle:source];
    return [UIImage imageFromIplImage:rotateImage([source IplImage], rotationAngle)];
}

- (NSArray *)splitImages {
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {            
            IplImage *square_rgb = cvCreateImage(cvGetSize(squares[j][i]), IPL_DEPTH_8U, 3);
            cvCvtColor(squares[j][i], square_rgb, CV_GRAY2RGB);
            UIImage *image = [UIImage imageFromIplImage:square_rgb];
            [result addObject:image];
        }
    }
    return result;
}

- (UIImage *)detectLines:(UIImage *)source {
    IplImage *img_rgb = [source IplImage];
    IplImage *img_bw = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    IplImage* dst = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,1);
    IplImage* color_dst = cvCreateImage(cvGetSize(img_rgb),IPL_DEPTH_8U,3);
    
    cvCvtColor(img_rgb, img_bw, CV_RGB2GRAY);
    cvCanny( img_bw, dst, 50, 100, 3 );
    cvCvtColor( dst, color_dst, CV_GRAY2RGB);

    CvMemStorage* storage = cvCreateMemStorage(0);
    CvSeq* lines = 0;
    
    lines = cvHoughLines2( dst, storage, CV_HOUGH_PROBABILISTIC, 1, CV_PI/180, 50, 50, 10);
    
    UIImage *image = [self detectBoundingRectangle:[UIImage imageFromIplImage:img_rgb]];
     
    img_rgb = [image IplImage];
    
    for (int i = 0; i < lines->total; i++ ){
        CvPoint* line = (CvPoint*)cvGetSeqElem(lines, i);
        if ((line[0].y < sudokuFrame[0].y || line[1].y < sudokuFrame[0].y || line[0].y > sudokuFrame[1].y || line[1].y > sudokuFrame[1].y) ||
            ((line[0].x < sudokuFrame[0].x || line[1].x < sudokuFrame[0].x || line[0].x > sudokuFrame[1].x || line[1].x > sudokuFrame[1].x))) {
            continue;
        }
        if (sqrtf(powf(line[1].x - line[0].x, 2) + powf(line[1].y - line[0].y, 2)) < img_rgb->width * 0.4) {
            continue;
        }
        cvLine(img_rgb, line[0], line[1], CV_RGB(255,0,255), 1, CV_AA, 0 );
    }

    cvReleaseMemStorage(&storage);
    cvReleaseImage(&dst);
    
    int boxWidth = sudokuFrame[1].x - sudokuFrame[0].x;
    int boxHeight = sudokuFrame[1].y - sudokuFrame[0].y;
    IplImage *onlySudokuBoxImage = cvCreateImage(cvSize(boxWidth, boxHeight),IPL_DEPTH_8U,3);
    GetSubImage(img_rgb, onlySudokuBoxImage, cvRect(sudokuFrame[0].x, sudokuFrame[0].y, boxWidth, boxHeight));

    //return [UIImage imageFromIplImage:onlySudokuBoxImage];
    
    IplImage *stripes[9];
    splitSudokuIntoVerticalStripes(onlySudokuBoxImage, stripes);
    
    for (int i = 0; i < 9; i++) {
        //IplImage *ipl = [self closeImage:stripes[i]];
        splitVerticalLineIntoDigits(stripes[i], squares[i]);
    }
    
    IplImage *square_rgb = cvCreateImage(cvGetSize(squares[8][8]), IPL_DEPTH_8U, 3);
    cvCvtColor(squares[8][8], square_rgb, CV_GRAY2RGB);
    
    //return [self closeImage:[UIImage imageFromIplImage:square_rgb]];
    return [UIImage imageFromIplImage:square_rgb];
}
@end
