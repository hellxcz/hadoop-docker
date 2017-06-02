
on port 8081 is running zeppelin
on port 8080 is running nifi

commands to build and run

docker build  -t heller/hadoop .

docker run -it heller/hadoop /etc/bootstrap.sh -p 8081:8081 -p 8080:8080 -bash 
