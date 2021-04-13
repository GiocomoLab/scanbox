function evt = sbx_get_ttlevents(fn)

data = load('-mat',[fn '.mj2_events']);
if(~isempty(data.ttl_events))
    evt = data.ttl_events(:,3)*256+data.ttl_events(:,2);
else
    evt = [];
end
