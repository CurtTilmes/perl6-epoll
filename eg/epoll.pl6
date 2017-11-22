use epoll;

my $epoll = epoll.new;

$epoll.add(0, :in, :edge-triggered);

for $epoll.wait
{
    .fd.say if .in;
}
