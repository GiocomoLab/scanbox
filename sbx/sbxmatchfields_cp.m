function r = sbxmatchfields_cp(fn1,fn2,th)

try
    m1 = load([fn1 '_rigid.segment'],'mask','-mat'); m1 = m1.mask;
    m2 = load([fn2 '_rigid.segment'],'mask','-mat'); m2 = m2.mask;
    
    i1 = load([fn1 '.align'],'m','-mat'); i1 = i1.m;
    i2 = load([fn2 '.align'],'m','-mat'); i2 = i2.m;
    
    i1 = (i1-min(i1(:)))/(max(i1(:))-min(i1(:)));    
    i2 = (i2-min(i2(:)))/(max(i2(:))-min(i2(:)));

catch
    error('You must segment first...')
end

% [u,v] = fftalign(m1~=0,m2~=0);
% m1 = circshift(m1,[u(1) v(1)]);

[movingPoints,fixedPoints] = cpselect(i1,i2,'Wait',true);
tform = fitgeotrans(movingPoints,fixedPoints,'affine');
m1 = imwarp(m1,tform,'OutputView',imref2d(size(m1)));
q = m1-floor(m1);
idx = find(q~=0);
m1(idx)=0;
m1 = imdilate(m1,strel('disk',1));

imshowpair(m1>0,m2>0);

s1 = setdiff(unique(m1(:)),0);
s2 = setdiff(unique(m2(:)),0);

O = zeros(max(s1),max(s2));
for(i=1:length(s1))
    idx1 = find(m1(:)==s1(i));
    for(j=1:length(s2))
        idx2 = find(m2(:)==s2(j));
        O(i,j) = length(intersect(idx1,idx2))/length(union(idx1,idx2));
    end
end

[i,j] = find(O>th);
L = [s1(i) s2(j)];

r.match = L;
r.AnotB = setdiff(1:max(m1(:)),L(:,1));
r.BnotA = setdiff(1:max(m2(:)),L(:,2));

figure

a = ismember(m1,L(:,1));
b = ismember(m2,L(:,2));
anotb = ismember(m1,r.AnotB);
bnota = ismember(m2,r.BnotA);
anotb = bwperim(anotb,8);
bnota = bwperim(bnota,8);

z = ones(size(a));
z(a)=2;
z(b)=3;
z(a&b)=4;
z(anotb) = 2;
z(bnota) = 3;

cm =[0 0 0;
    0 1 0;
    1 0 0;
    1 1 0];

imshow(z,cm)
axis off;
truesize;


function [u,v] = fftalign(A,B)

N = min(size(A));
A = A(round(size(A,1)/2)-N/2 + 1 : round(size(A,1)/2)+ N/2, round(size(A,2)/2)-N/2 + 1 : round(size(A,2)/2)+ N/2 );
B = B(round(size(A,1)/2)-N/2 + 1 : round(size(A,1)/2)+ N/2, round(size(B,2)/2)-N/2 + 1 : round(size(B,2)/2)+ N/2 );

C = fftshift(real(ifft2(fft2(A).*fft2(rot90(B,2)))));
[ii,jj] = find(C==max(C(:)));
u = N/2-ii;
v = N/2-jj;