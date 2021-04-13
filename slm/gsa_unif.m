function ph = gsa_unif(dest,varargin)

gdest = gpuArray(dest);

%a = gpuArray(exp(1i*rand(size(gdest),'single')*2*pi));

if(nargin>1)
    a = gpuArray(varargin{1});
    N = varargin{2};
else
    a = zeros(size(dest),'single','gpuArray');
    N = 15;
end

for k=1:N
    b = exp(1i*angle(a));
    c = fft2(b);
    d = gdest .* exp(1i*angle(c));
    a = ifft2(d);
end
ph = gather(angle(a));
%ph = uint8((ph + pi)/(2*pi)*255);
