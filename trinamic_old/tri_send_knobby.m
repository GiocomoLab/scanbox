function r = tri_send_knobby(motor,val)

global tri sbconfig;

motor = uint8(motor);
val = typecast(uint16(val),'uint8');
msg = zeros(1,9,'uint8');

if(nargin<5)
    while(tri.Data(1)~=0)
    end
    msg = tri.Data(2:end);
else
    msg = [];
end

try
    r.status = msg(3);
    value = int32(0);
    k=1;
    for(i=0:3)
        for(j=1:8)
            value = bitset(value,k,bitget(msg(8-i),j));
            k = k+1;
        end
    end
    
    r.value = value;
    
catch
    r = [];
end




