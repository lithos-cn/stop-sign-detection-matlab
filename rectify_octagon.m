function [rectified, tform, status] = rectify_octagon(img, src_pts, dst_pts, out_size)
% RECTIFY_OCTAGON Warp eight source vertices to template coordinates.

rectified = [];
tform = [];
status = '校正尚未开始';

try
    src_pts = double(src_pts);
    dst_pts = double(dst_pts);

    % Require eight source and destination vertices.
    if size(src_pts,1) ~= 8 || size(dst_pts,1) ~= 8
        status = '源顶点或模板顶点数量不是8';
        return;
    end

    % Estimate the projective transform.
    tform = fitgeotform2d(src_pts, dst_pts, 'projective');

    % Fix the output view to the template dimensions.
    rout = imref2d([out_size(1), out_size(2)]);

    rectified = imwarp(img, tform, 'OutputView', rout, 'FillValues', 0);

    % Convert the warped image to grayscale.
    if size(rectified, 3) == 3
        rectified = rgb2gray(rectified);
    end

    % Reject empty or nearly black results.
    if isempty(rectified) || mean(rectified(:)) < 1
        rectified = [];
        status = '变换结果为空或几乎全黑';
    else
        status = '已校正';
    end

catch ME
    rectified = [];
    tform = [];
    status = ME.message;
end
end
