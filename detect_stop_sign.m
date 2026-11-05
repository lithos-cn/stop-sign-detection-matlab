function [best_pts, best_score, best_rectified, debug_info] = detect_stop_sign(img, template, template_pts, param)
% DETECT_STOP_SIGN Return the highest-scoring rectified octagon candidate.
debug_info.mask = [];
best_score = -1;  % Initial value before a valid match is selected.
best_pts = [];
best_rectified = [];

[mask, hsv_img] = red_segmentation(img, param);
debug_info.mask = mask;
[candidates, diagnostics] = find_octagon_candidates(mask, param);
debug_info.candidates = candidates;
debug_info.best_candidate = 0;
debug_info.best_core_score = -1;
debug_info.best_full_score = -1;
debug_info.best_red_fraction = 0;
verbose = isfield(param, 'debug_candidates') && param.debug_candidates;
fprintf('  候选诊断：连通域 %d，尺寸通过 %d，形状通过 %d；超过旧面积上限 %d\n', ...
        diagnostics.regions, diagnostics.size_pass, ...
        diagnostics.shape_pass, diagnostics.above_old_max_area);
if isempty(candidates)
    fprintf('  未找到候选八边形，NCC 未计算\n');
    return;
end
fprintf('  找到 %d 个候选区域\n', numel(candidates));

% Match vertex winding and the starting corner before rectification.
target_winding = polygon_winding(template_pts);
target_top_left = top_left_index(template_pts);
H = hsv_img(:,:,1);
S = hsv_img(:,:,2);
V = hsv_img(:,:,3);
red_pixels = (H <= 0.10 | H >= 0.95) & S >= 0.20 & V >= 0.12;
% Include red-dominant pixels outside the HSV red range.
rgb = im2double(img);
R = rgb(:,:,1); G = rgb(:,:,2); B = rgb(:,:,3);
red_pixels = red_pixels | (R > 0.22 & R > 1.12*G & R > 1.12*B);
red_rejected = 0;
for k = 1:numel(candidates)
    pts = candidates{k};
    region = poly2mask(pts(:,1), pts(:,2), size(mask,1), size(mask,2));
    red_fraction = nnz(red_pixels & region) / max(nnz(region), 1);
    center = mean(pts, 1);
    if red_fraction < 0.20
        red_rejected = red_rejected + 1;
        if verbose
            fprintf('    候选%02d (%.0f, %.0f): 红色占比 %.2f，颜色排除\n', ...
                    k, center(1), center(2), red_fraction);
        end
        continue;
    end
    if polygon_winding(pts) ~= target_winding
        pts = flipud(pts);
    end
    source_top_left = top_left_index(pts);
    shifted_pts = circshift(pts, target_top_left - source_top_left, 1);
    [rectified, ~, warp_status] = rectify_octagon(img, shifted_pts, template_pts, size(template));
    if isempty(rectified)
        if verbose
            fprintf('    候选%02d (%.0f, %.0f): 红色占比 %.2f，校正失败：%s\n', ...
                    k, center(1), center(2), red_fraction, warp_status);
        end
        continue;
    end
    if param.use_histeq
        rectified = histeq(rectified);
    end
    [score, ncc_reason, ncc_detail] = compute_ncc_with_mask(rectified, template, template_pts);
    if verbose
        fprintf('    候选%02d (%.0f, %.0f): 红色占比 %.2f，NCC %.3f（%s）\n', ...
                k, center(1), center(2), red_fraction, score, ncc_reason);
    end
    if score > best_score
        best_score = score;
        best_pts = shifted_pts;
        best_rectified = rectified;
        debug_info.best_candidate = k;
        debug_info.best_core_score = ncc_detail.core;
        debug_info.best_full_score = ncc_detail.full;
        debug_info.best_red_fraction = red_fraction;
    end
end
if red_rejected > 0
    fprintf('  排除颜色不符合红色标志牌的候选 %d 个\n', red_rejected);
end
end

function winding = polygon_winding(pts)
next = pts([2:end 1], :);
twice_area = sum(pts(:,1).*next(:,2) - next(:,1).*pts(:,2));
winding = sign(twice_area);
end

function index = top_left_index(pts)
% Choose the leftmost vertex within the top band.
height = max(pts(:,2)) - min(pts(:,2));
top = find(pts(:,2) <= min(pts(:,2)) + 0.18 * height);
[~, position] = min(pts(top,1));
index = top(position);
end
