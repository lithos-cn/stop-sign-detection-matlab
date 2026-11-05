function [score, reason, detail] = compute_ncc_with_mask(rectified, template, template_pts)
% COMPUTE_NCC_WITH_MASK Match full-face and text-region NCC over small shifts and scales.
score = -1;
reason = 'Input image is empty';
detail = struct('full', -1, 'core', -1);
if isempty(rectified) || isempty(template)
    return;
end

if size(template, 3) == 3
    template = rgb2gray(template);
end
if size(rectified, 3) == 3
    rectified = rgb2gray(rectified);
end
template = im2double(template);
rectified = im2double(rectified);
if ~isequal(size(template), size(rectified))
    rectified = imresize(rectified, size(template));
end

[height, width] = size(template);
if nargin >= 3 && ~isempty(template_pts)
    % Restrict matching to the annotated template polygon.
    mask = poly2mask(template_pts(:,1), template_pts(:,2), height, width);
else
    % Use a central mask when template vertices are omitted.
    mask = false(height, width);
    mask(round(height*0.15):round(height*0.85), ...
         round(width*0.15):round(width*0.85)) = true;
end
margin = max(1, round(0.035 * min(height, width)));
mask = imerode(mask, strel('disk', margin));
if nnz(mask) < 80
    reason = 'Template interior mask is too small';
    return;
end

% Smooth noise before mean-centered correlation.
template = imgaussfilt(template, 0.7);
rectified = imgaussfilt(rectified, 0.7);
t = template(mask);
t = t - mean(t);
t_norm = norm(t);
if t_norm < 0.025 * sqrt(numel(t))
    reason = 'Insufficient template intensity variation';
    return;
end

% Reject candidates with insufficient intensity variation.
r0 = rectified(mask);
if std(r0) < 0.045
    reason = 'Insufficient candidate intensity variation';
    return;
end
% Measure edge strength with Sobel filters.
sobel = fspecial('sobel') / 8;
gx = imfilter(rectified, sobel, 'replicate');
gy = imfilter(rectified, sobel', 'replicate');
edge_strength = mean(hypot(gx(mask), gy(mask)));
% Require edge strength relative to the candidate contrast.
if edge_strength < max(0.0011, 0.018 * std(r0))
    reason = 'Insufficient candidate edge strength';
    return;
end

[xx, yy] = meshgrid(1:width, 1:height);
% Focus the secondary mask on the central STOP lettering.
mask_x = xx(mask);
mask_y = yy(mask);
span_x = max(mask_x) - min(mask_x);
span_y = max(mask_y) - min(mask_y);
core = mask_x >= min(mask_x) + 0.10*span_x & ...
       mask_x <= max(mask_x) - 0.10*span_x & ...
       mask_y >= min(mask_y) + 0.25*span_y & ...
       mask_y <= max(mask_y) - 0.25*span_y;
t_core = template(mask);
t_core = t_core(core);
t_core = t_core - mean(t_core);
core_valid = numel(t_core) >= 80 && norm(t_core) > 0.025*sqrt(numel(t_core));
best_full = -1;
best_core = -1;
cx = (width + 1) / 2;
cy = (height + 1) / 2;
scales = [0.94, 1, 1.06];
dxs = [-0.035, 0, 0.035] * width;
dys = [-0.035, 0, 0.035] * height;
reason = 'No valid alignment';

for scale = scales
    for dx = dxs
        for dy = dys
            xq = cx + (xx(mask) - cx) * scale + dx;
            yq = cy + (yy(mask) - cy) * scale + dy;
            if any(xq < 1 | xq > width | yq < 1 | yq > height)
                continue;
            end
            r = interp2(rectified, xq, yq, 'linear');
            if any(~isfinite(r)) || std(r) < 0.045
                continue;
            end
            r_centered = r - mean(r);
            full_score = (r_centered' * t) / (norm(r_centered) * t_norm + eps);
            best_full = max(best_full, full_score);
            candidate_score = full_score;
            if core_valid
                r_core = r(core);
                r_core = r_core - mean(r_core);
                if std(r_core) >= 0.035
                    core_score = (r_core' * t_core) / (norm(r_core)*norm(t_core) + eps);
                    best_core = max(best_core, core_score);
                    % Keep full-face NCC or the weighted full-face/text score.
                    candidate_score = max(full_score, 0.45*full_score + 0.55*core_score);
                end
            end
            score = max(score, candidate_score);
            reason = 'Computed';
        end
    end
end
score = max(-1, min(1, score));
% Report independent maxima; their alignments may differ.
detail.full = best_full;
detail.core = best_core;
if ~strcmp(reason, 'No valid alignment')
    reason = sprintf('Full-face %.3f, text-region %.3f', best_full, best_core);
end
end
