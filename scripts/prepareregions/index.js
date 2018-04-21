#!/usr/bin/env node

var fs = require('fs');
var path = require('path');
var yaml = require('js-yaml');
var NodeGit = require("nodegit");
var tar = require("tar");

const repository = 'devops-config';
const cloneURL = `https://github.ibm.com/ids-env/${repository}`;
const cloneOptions = {
  fetchOpts: {
    callbacks: {
      certificateCheck: () => {
        return 1;
      },
      credentials: () => {
        return NodeGit.Cred.userpassPlaintextNew(process.env.IDS_TOKEN, 'x-oauth-basic');
      }
    }
  }
};

const cloneRepository = NodeGit.Clone(cloneURL, repository, cloneOptions)
  .then((repo) => {
    try {
      var chartinfo = path.join(__dirname, 'umbrellachart.info'),
        chartinfocontents = fs.readFileSync(chartinfo, 'utf8'),
        chartinfoobj = yaml.load(chartinfocontents);

      tar.x({
          strip: 1,
          file: path.join(__dirname, chartinfoobj.tarfile)
        }, [chartinfoobj.name + '/requirements.yaml', chartinfoobj.name + '/requirements.lock'])
        .then(_ => {
          try {
            var req = path.join(__dirname, 'requirements.yaml'),
              reqcontents = fs.readFileSync(req, 'utf8'),
              reqobj = yaml.load(reqcontents);
            var lock = path.join(__dirname, 'requirements.lock'),
              lockcontents = fs.readFileSync(lock, 'utf8'),
              lockobj = yaml.load(lockcontents);
            var env = path.join(__dirname, repository, 'charts', 'requirements.' + process.env.IDS_JOB_NAME + '.yaml'),
              envcontents = fs.readFileSync(env, 'utf8'),
              envobj = yaml.load(envcontents);

            var aliases = {};
            var tokens;

            fs.mkdirSync(path.join(__dirname, process.env.ARCHIVE_DIR))

            var repos = fs.createWriteStream(path.join(__dirname, process.env.ARCHIVE_DIR, 'add_repos.sh'));

            reqobj.dependencies = reqobj.dependencies.filter((dependency) => {
              var retval = true;
              if (dependency.hasOwnProperty("tags") &&
                dependency.tags.includes("environment")) {
                retval = false;
              }
              lockdep = lockobj.dependencies.find(x => x.name === dependency.name);
              dependency.version = lockdep.version;
              aliases[dependency.repository] = lockdep.repository;
              return retval;
            });
            reqobj.dependencies = reqobj.dependencies.concat(envobj.dependencies);
            fs.writeFile(path.join(__dirname, process.env.ARCHIVE_DIR, 'requirements.yaml'), yaml.dump(reqobj), 'utf8', function(err) {
              if (err) {
                throw err;
              }
              console.log("Versions written to requirements.yaml!");
            });

            repos.write("#!/bin/bash\n");
            Object.keys(aliases).forEach((alias) => {
              tokens = alias.split(':');
              if (tokens[0] === "alias") {
                repos.write("helm repo add " + tokens[1] + " " + aliases[alias] + '\n');
              }
            });
            repos.end();
          } catch (err) {
            console.error(err.stack || String(err));
          }
        })
        .catch((err) => {
          console.error(err.stack || String(err));
        });
    } catch (err) {
      console.error(err.stack || String(err));
    }
  })
  .catch((err) => {
    console.error(err.stack || String(err));
  });
