#!/usr/bin/env node
"use strict";
require('core-js');
var child_process = require('child_process');
var fs = require('fs');
var path = require('path');
var request = require('request');
var yaml = require('js-yaml');

var GITHUB_API = "https://github.com/api/v3";
var TOKEN = process.env.GITHUB_TOKEN;

// var remote_path_parts = package_json.binary.remote_path
//   .replace(/^\/|\/$/, '').split('/');
var OWNER = 'mqlight';
var REPO = 'ruby-mqlight';
var TAG = yaml.safeLoad(fs.readFileSync('version.yaml', 'utf8'));

var merge = function(baseo, newo) {
  if (newo) {
    Object.keys(newo).forEach(function(k) {
      var v = newo[k];
      if (typeof(v)==='object' && !Buffer.isBuffer(v)) {
        baseo[k] = merge(baseo[k] || Object.create(null), v);
      } else {
        baseo[k] = v;
      }
    });
  }
  return baseo;
};

var api = function(options, not_json) {
  return new Promise(function(resolve, reject) {
    options = merge({
      url: GITHUB_API + '/repos/' + OWNER + '/' + REPO + '/releases',
      headers: {
        Authorization: 'token ' + TOKEN
      }
    }, options);
    request(options, function(error, response, body) {
      if (error) { return reject(error); }
      if (!(response.statusCode >= 200 && response.statusCode <= 299)) {
        var msg = 'ERROR ' + response.statusCode+': ' + response.statusMessage;
        try {
          body = JSON.parse(body);
          if (body.message) {
            msg += ': ' + body.message;
          }
        } catch (e) { /* ignore */ }
        msg += ' (' + options.url + ')';
        return reject(msg);
      }
      if (!not_json) { body = JSON.parse(body); }
      resolve({ resp: response, body: body});
    });
  });
};

var npgReveal = function() {
  return new Promise(function(resolve, reject) {
    fs.readdir('./pkg', function(err, files) {
      if (err) { return reject(error); }
      var a = files.filter(function(asset) {
        console.log(asset);
        return asset.endsWith('.gem');
      });
      if (!a || a.length === 0) { return reject('"no matching .gem"'); }
      resolve({'package_name': a[0], 'staged_tarball': 'pkg/' + a[0]});
    });
  }).then(function(json) { return json; });
};

var getReleases = function() {
  return api();
};

var makeRelease = function() {
  return api({
    method: 'POST',
    body: JSON.stringify({
      tag_name: TAG,
      name: TAG,
      draft: true
    }),
    headers: {
      'Content-Type': 'application/json'
    }
  }).then(function(resp) { return resp.body; });
};

var deleteAsset = function(asset) {
  return api({
    method: 'DELETE',
    url: asset.url
  }, true /* no json */);
};

var uploadAsset = function(reveal, release) {
  return api({
    url: release.upload_url.replace(/\{\?[^\}]*\}$/, ''),
    qs: { name: reveal.package_name },
    method: 'POST',
    headers: {
      'Content-Type': 'application/gzip'
    },
    body: fs.readFileSync(path.join(__dirname, reveal.staged_tarball))
  }).then(function(resp) { return resp.body; });
};

var publish = function() {
  var release, asset, reveal;
  return npgReveal().then(function(_reveal) {
    reveal = _reveal;
    return getReleases();
  }).then(function(resp) {
    // look through the releases for something matching $TAG
    var r = resp.body.filter(function(release) {
      return release.tag_name === TAG;
    });
    if (r.length === 0) {
      // create a new release!
      return makeRelease();
    } else {
      return r[0];
    }
  }).then(function(_release) {
    release = _release;
    // okay, see if this file was previously uploaded
    var a = release.assets.filter(function(asset) {
      return asset.name === reveal.package_name;
    });
    if (a.length > 0) {
      return deleteAsset(a[0]);
    }
  }).then(function() {
    return uploadAsset(reveal, release);
  });
};

publish().then(function(asset) {
  console.log(asset.name + ' uploaded successfully to');
  console.log(asset.browser_download_url);
}, function(e) {
  setTimeout(function() { throw e; }, 0);
});
