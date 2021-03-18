#!/usr/bin/env perl
use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

use_ok 'Mojolicious::Plugin::CHI::Route';

my $t = Test::Mojo->new;
my $app = $t->app;

$app->plugin('CHI' => {
  xyz => {
    driver => 'Memory',
    global => 1
  }
});
$app->plugin('CHI::Route' => {
  namespace => 'xyz'
});

get('/cool')->requires('chi' => { key => sub { 'abc' } })->to(
  cb => sub {
    my $c = shift;
    $c->res->headers->header('X-Funny' => 'hi');
    return $c->render(
      text => 'works: cool',
      format => 'txt'
    );
  }
);

get('/foo')->requires('chi')->to(
  cb => sub {
    return shift->render(
      status => 404,
      text => 'works: not',
      format => 'txt'
    );
  }
);

$t->get_ok('/cool')
  ->status_is(200)
  ->content_type_is('text/plain;charset=UTF-8')
  ->content_is('works: cool')
  ->header_is('X-Funny','hi')
  ->header_is('X-From-Cache', undef)
  ;

$t->get_ok('/cool')
  ->status_is(200)
  ->content_type_is('text/plain;charset=UTF-8')
  ->content_is('works: cool')
  ->header_is('X-Funny','hi')
  ->header_is('X-From-Cache','1')
  ;

$t->get_ok('/cool')
  ->status_is(200)
  ->content_type_is('text/plain;charset=UTF-8')
  ->content_is('works: cool')
  ->header_is('X-Funny','hi')
  ->header_is('X-From-Cache','1')
  ;

$t->get_ok('/foo')
  ->status_is(404)
  ->content_type_is('text/plain;charset=UTF-8')
  ->content_is('works: not')
  ->header_is('X-From-Cache',undef)
  ;

$t->get_ok('/foo')
  ->status_is(404)
  ->content_type_is('text/plain;charset=UTF-8')
  ->content_is('works: not')
  ->header_is('X-From-Cache',undef)
  ;

done_testing;
