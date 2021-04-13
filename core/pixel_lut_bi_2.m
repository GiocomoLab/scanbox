function [S,pIdx,pIdxA,cdIdx,ncol] = pixel_lut_bi_2(nlines)

global sbconfig;

ncol = 796;
nsamp =  round(sbconfig.lasfreq / sbconfig.resfreq);
M = ncol+2;

n0 = linspace(1,-1,M);
n1 = linspace(-1,1,M);
n1 = n1(n1<cos(9000/nsamp*2*pi));

x = [n0(2:end-1) n0(2:length(n1))];

n = acos(x)*nsamp/(2*pi);
n(ncol+1:end) = n(ncol+1:end) + nsamp/2;

S = floor(n)-1;
S = [S; S+1; S+2 ; S+3];        % indices
S = reshape(S,1,[]);

skip = 2*ncol - length(n);

%% prepare post index variables

sz = [2 ncol nlines];
postIdx = reshape(0:prod(sz)-1,sz);
postIdx(:,:,2:2:end) = postIdx(:,end:-1:1,2:2:end);   % reverse even rows
postIdx(:,1:skip,2:2:end) = NaN;
[z,j] = sort(postIdx(:));
j = j(~isnan(z));
pIdx = j-1;

% output channels

sz = [1 ncol nlines];                                  % for chA
postIdx = reshape(0:prod(sz)-1,sz);
postIdx(:,:,2:2:end) = postIdx(:,end:-1:1,2:2:end);    % reverse even rows
postIdx(:,1:skip,2:2:end) = NaN;
[z,j] = sort(postIdx(:));
j = j(~isnan(z));
pIdxA = j-1;

sz = [3 ncol nlines];                                 % for color display
postIdx = reshape(0:prod(sz)-1,sz);
postIdx(:,:,2:2:end) = postIdx(:,end:-1:1,2:2:end);   % reverse even rows
postIdx(:,1:skip,2:2:end) = NaN;
[z,j] = sort(postIdx(:));
j = j(~isnan(z));
cdIdx = j-1;

pIdx =  uint32(pIdx);
pIdxA = uint32(pIdxA);
cdIdx = uint32(cdIdx);



