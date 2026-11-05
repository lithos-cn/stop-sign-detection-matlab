function [mask, hsv_img] = red_segmentation(img, param)
% RED_SEGMENTATION Create a cleaned red mask using HSV and RGB rules.
if size(img,3) ~= 3
    error('Input must be an RGB color image');
end

img = im2double(img);

% Threshold red hues across the HSV hue boundary.
hsv_img = rgb2hsv(img);
H = hsv_img(:,:,1);
S = hsv_img(:,:,2);
V = hsv_img(:,:,3);

mask_h = (H >= param.hsv_h_low) | (H <= param.hsv_h_high);
mask_s = S >= param.hsv_s_low;
mask_v = V >= param.hsv_v_low;
mask_hsv = mask_h & mask_s & mask_v;

% Supplement HSV segmentation with red-dominant RGB pixels.
R = img(:,:,1);
G = img(:,:,2);
B = img(:,:,3);
mask_rgb = (R > 0.35) & (R > G*1.15) & (R > B*1.15);

% Combine both color masks.
mask = mask_hsv | mask_rgb;

% Remove small regions, close gaps, and fill holes.
se = strel('disk', 4);
mask = imopen(mask, se);
mask = imclose(mask, se);
mask = bwareaopen(mask, round(param.min_area * 0.35));
mask = imfill(mask, 'holes');

% Relax the RGB thresholds if too few foreground pixels remain.
if sum(mask(:)) < param.min_area
    mask_rgb2 = (R > 0.28) & (R > G*1.08) & (R > B*1.08);
    mask = mask_hsv | mask_rgb2;
    mask = imopen(mask, se);
    mask = imclose(mask, se);
    mask = bwareaopen(mask, round(param.min_area * 0.3));
    mask = imfill(mask, 'holes');
end
end
