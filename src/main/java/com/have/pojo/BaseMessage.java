
package com.have.pojo;

import lombok.Data;

/**
 * @author C.W
 * @date 2021/11/26 22:20
 * @description 基础消息响应
 */
@Data
public class BaseMessage {

    /**
     * 接收方帐号（收到的OpenID）
     */
    private String ToUserName;
    /**
     * 开发者微信号
     */
    private String FromUserName;
    /**
     * 消息创建时间 （整型）
     */
    private long CreateTime;

    /**
     * 消息类型
     */
    private String MsgType;

    /**
     * 位0x0001被标志时，星标刚收到的消息
     */
    private int FuncFlag;

}