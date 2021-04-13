function [ph,r] = gsa(src,dest)

gsrc = gpuArray(src);
gdest = gpuArray(dest);
a = gpuArray(exp(1i*rand(size(gdest),'single')*2*pi));
for k=1:40
    b = abs(gsrc) .* exp(1i*angle(a));
    c = fft2(b);
    d = abs(gdest) .* exp(1i*angle(c));
    a = ifft2(d);
end
ph = gather(angle(a));
r = abs(fft2(exp(1i*angle(a))));
ph = uint8((ph + pi)/(2*pi)*256);
