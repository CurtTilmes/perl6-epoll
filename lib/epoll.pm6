use NativeCall;

enum (
    EPOLL_CTL_ADD => 1,
    EPOLL_CTL_DEL => 2,
    EPOLL_CTL_MOD => 3
);

enum EPOLL_EVENTS (
    EPOLLIN      => 0x001,
    EPOLLPRI     => 0x002,
    EPOLLOUT     => 0x004,
    EPOLLRDNORM  => 0x040,
    EPOLLRDBAND  => 0x080,
    EPOLLWRNORM  => 0x100,
    EPOLLWRBAND  => 0x200,
    EPOLLMSG     => 0x400,
    EPOLLERR     => 0x008,
    EPOLLHUP     => 0x010,
    EPOLLRDHUP   => 0x2000,
    EPOLLWAKEUP  => 0x20000000,
    EPOLLONESHOT => 0x40000000,
    EPOLLET      => 0x80000000
);

class epoll-event is repr('CStruct')
{
    has uint32 $.events;
    has int32  $.fd;
    has int32  $.pad;

    method in  { so $!events +| EPOLLIN }
    method out { so $!events +| EPOLLOUT }
}

sub sys_close(int32 --> int32) is native is symbol('close') {}

sub calloc(size_t, size_t --> Pointer) is native {}

sub free(Pointer) is native {}

sub epoll_create1(int32 --> int32) is native {}

sub epoll_ctl(int32, int32, int32, epoll-event --> int32) is native {}

sub epoll_wait(int32, Pointer, int32, int32 --> int32) is native {}

class epoll
{
    has $.epfd;
    has $.maxevents = 1;
    has Pointer $.events;

    submethod TWEAK
    {
        $!epfd = epoll_create1(0);
        die "Failure creating epoll" if $!epfd == -1;
        $!events = calloc($!maxevents, nativesizeof(epoll-event));
        die "Out of memory" unless $!events;
    }

    submethod DESTROY
    {
        sys_close($!epfd) if $!epfd >= 0;
        $!epfd = -1;
        free($_) with $!events;
        $!events = Pointer;
    }

    method add(int32 $fd, Bool :$in = False,
                          Bool :$out = False,
                          Bool :$priority = False,
                          Bool :$edge-triggered = False,
                          Bool :$one-shot = False)
    {
        my int32 $events = EPOLLIN      * $in
                        +| EPOLLPRI     * $priority
                        +| EPOLLOUT     * $out
                        +| EPOLLET      * $edge-triggered
                        +| EPOLLONESHOT * $one-shot;

        my $event = epoll-event.new(:$events, :$fd);

        if epoll_ctl($!epfd, EPOLL_CTL_ADD, $fd, $event) < 0
        {
            die 'Failed add in epoll_ctl()';
        }

        self
    }

    method remove(int32 $fd)
    {
        if -1 == epoll_ctl($!epfd, EPOLL_CTL_DEL, $fd, epoll-event) < 0
        {
            die 'Failed remove in epoll_ctl()';
        }
    }

    method wait(int32 :$timeout = -1)
    {
        my $count = epoll_wait($!epfd, $!events, $!maxevents, $timeout);

        die 'Failed in epoll_wait()' if $count < 0;

        do for ^$count -> $i
        {
            nativecast(epoll-event,
                       Pointer.new(+$!events + $i*nativesizeof(epoll-event)))
        }
    }
}
