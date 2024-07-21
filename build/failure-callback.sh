#!/bin/bash

cat > payload.json <<MSG
{
    "subject": "[TeaCon 甲辰] $TEAM_ID 构建失败通知",
    "msg": "TeaCon 甲辰 参与者您好：\n\n您的作品（模组 ID $TEAM_ID）在最新一次构建（第 $GITHUB_RUN_NUMBER 次构建）中出错，未能产出 jar 文件。\n您可以通过该 URL 获得构建详情：$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID \n如有疑问，请联系 TeaCon 执行委员会成员。\n\n\n顺颂时祺\nTeaCon 执行委员会",
    "teams": [ $TEAM_SEQ ]
}
MSG

curl -s -X POST -d @payload.json -H "Authorization: Bearer $BILUOCHUN_TOKEN" $BILUOCHUN_URL/api/v2/notify